defmodule Dash.Pipelines.Executor do
  @moduledoc """
  Executes pipeline runs by orchestrating data fetching, transformation, storage, and delivery.

  The Executor is responsible for the complete pipeline execution flow:
  1. Create execution log (started)
  2. Fetch data from external source
  3. Transform data using mappings
  4. Store as pipeline events (if persist_data enabled)
  5. Send to configured sinks
  6. Update execution log (completed/error)
  7. Broadcast execution status via PubSub

  ## Example

      pipeline = Dash.Pipelines.get_pipeline!(pipeline_id)
      {:ok, log} = Executor.execute(pipeline)
  """

  require Logger
  alias Dash.Pipelines.{DataMapper, ExecutionLog, PipelineEvent}

  # Allow adapter to be configured for testing
  @default_adapter Dash.Adapters.External

  @doc """
  Executes a pipeline and returns the execution log.

  Returns `{:ok, execution_log}` on success (even if no data was fetched).
  The execution log will contain the status and any error information.
  """
  @spec execute(Ash.Resource.record()) :: {:ok, Ash.Resource.record()} | {:error, term()}
  def execute(pipeline) do
    started_at = DateTime.utc_now()

    # Create initial execution log (system operation, no authorization needed)
    {:ok, log} =
      ExecutionLog
      |> Ash.Changeset.for_create(:create, %{
        pipeline_id: pipeline.id,
        status: :success,
        started_at: started_at
      })
      |> Ash.create(authorize?: false)

    # Execute pipeline
    result = do_execute(pipeline, log, started_at)

    # Return final log
    case result do
      {:ok, final_log} ->
        Logger.info("Pipeline #{pipeline.id} executed successfully")
        {:ok, final_log}

      {:error, reason} ->
        Logger.error("Pipeline #{pipeline.id} execution failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp do_execute(pipeline, log, started_at) do
    with {:ok, data, metadata} <- fetch_data(pipeline),
         {:ok, transformed} <- transform_data(pipeline, data),
         {:ok, stored_count} <- maybe_persist_data(pipeline, transformed),
         {:ok, _sink_results} <- send_to_sinks(pipeline, transformed) do
      # Calculate duration
      completed_at = DateTime.utc_now()
      duration_ms = DateTime.diff(completed_at, started_at, :millisecond)

      # Determine final status
      status = if length(data) == 0, do: :no_data, else: :success

      # Update log with success (system operation)
      log
      |> Ash.Changeset.for_update(:update, %{
        status: status,
        completed_at: completed_at,
        duration_ms: duration_ms,
        records_fetched: length(data),
        records_stored: stored_count,
        source_response_time_ms: metadata[:response_time_ms],
        metadata: metadata
      })
      |> Ash.update(authorize?: false)
    else
      {:error, :fetch, reason, response_time} ->
        update_log_with_error(log, started_at, :source_fetch, reason, %{
          source_response_time_ms: response_time
        })

      {:error, :transform, reason} ->
        update_log_with_error(log, started_at, :transformation, reason, %{})

      {:error, :storage, reason} ->
        update_log_with_error(log, started_at, :storage, reason, %{})

      {:error, :sink, reason} ->
        update_log_with_error(log, started_at, :sink_delivery, reason, %{})

      {:error, reason} ->
        update_log_with_error(log, started_at, :validation, inspect(reason), %{})
    end
  end

  defp fetch_data(pipeline) do
    Logger.debug("Fetching data for pipeline #{pipeline.id} from #{pipeline.source_type}")

    adapter = Application.get_env(:dash, :external_adapter, @default_adapter)

    case adapter.fetch(pipeline.source_type, pipeline.source_config) do
      {:ok, data, metadata} ->
        Logger.debug(
          "Fetched #{length(data)} record(s) for pipeline #{pipeline.id} in #{metadata.response_time_ms}ms"
        )

        {:ok, data, metadata}

      {:error, reason} ->
        {:error, :fetch, reason, nil}
    end
  rescue
    error ->
      {:error, :fetch, Exception.message(error), nil}
  end

  defp transform_data(pipeline, data) when length(data) == 0 do
    Logger.debug("No data to transform for pipeline #{pipeline.id}")
    {:ok, []}
  end

  defp transform_data(pipeline, data) do
    Logger.debug("Transforming #{length(data)} record(s) for pipeline #{pipeline.id}")

    with {:ok, loaded_pipeline} <- Ash.load(pipeline, :data_mappings, authorize?: false),
         {:ok, mappings} <- extract_mappings(loaded_pipeline.data_mappings) do
      case DataMapper.transform(data, mappings) do
        {:ok, transformed} ->
          Logger.debug("Successfully transformed #{length(transformed)} record(s)")
          {:ok, transformed}

        {:error, reason} ->
          {:error, :transform, reason}
      end
    else
      {:error, reason} ->
        {:error, :transform, "Failed to load mappings: #{inspect(reason)}"}
    end
  rescue
    error ->
      {:error, :transform, Exception.message(error)}
  end

  defp extract_mappings(data_mappings) do
    mappings =
      Enum.map(data_mappings, fn mapping ->
        %{
          source_field: mapping.source_field,
          target_field: mapping.target_field,
          required: mapping.required,
          transformation_type: mapping.transformation_type
        }
      end)

    {:ok, mappings}
  end

  defp maybe_persist_data(_pipeline, []), do: {:ok, 0}

  defp maybe_persist_data(pipeline, transformed_data) do
    if pipeline.persist_data do
      persist_data(pipeline, transformed_data)
    else
      Logger.debug("Skipping data persistence for pipeline #{pipeline.id} (persist_data=false)")
      {:ok, 0}
    end
  end

  defp persist_data(pipeline, transformed_data) do
    Logger.debug("Persisting #{length(transformed_data)} record(s) for pipeline #{pipeline.id}")

    results =
      Enum.map(transformed_data, fn record ->
        PipelineEvent
        |> Ash.Changeset.for_create(:create, %{
          data: record,
          metadata: %{pipeline_id: pipeline.id},
          pipeline_id: pipeline.id
        })
        |> Ash.create(authorize?: false)
      end)

    # Check if all succeeded
    errors = Enum.filter(results, fn result -> match?({:error, _}, result) end)

    if length(errors) > 0 do
      {:error, :storage, "Failed to store #{length(errors)} record(s)"}
    else
      {:ok, length(results)}
    end
  rescue
    error ->
      {:error, :storage, Exception.message(error)}
  end

  defp send_to_sinks(_pipeline, []), do: {:ok, []}

  defp send_to_sinks(pipeline, transformed_data) do
    if length(pipeline.sink_configs) == 0 do
      Logger.debug("No sinks configured for pipeline #{pipeline.id}")
      {:ok, []}
    else
      Logger.debug(
        "Sending #{length(transformed_data)} record(s) to #{length(pipeline.sink_configs)} sink(s)"
      )

      # For Week 3-4, just log that we would send to sinks
      # Actual sink delivery will be implemented later
      {:ok, []}
    end
  rescue
    error ->
      {:error, :sink, Exception.message(error)}
  end

  defp update_log_with_error(log, started_at, error_type, error_message, extra_fields) do
    completed_at = DateTime.utc_now()
    duration_ms = DateTime.diff(completed_at, started_at, :millisecond)

    log
    |> Ash.Changeset.for_update(
      :update,
      Map.merge(
        %{
          status: :error,
          completed_at: completed_at,
          duration_ms: duration_ms,
          error_type: error_type,
          error_message: error_message
        },
        extra_fields
      )
    )
    |> Ash.update(authorize?: false)
  end
end
