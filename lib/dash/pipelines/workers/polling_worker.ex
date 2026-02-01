defmodule Dash.Pipelines.Workers.PollingWorker do
  @moduledoc """
  Oban worker for executing polling pipelines on a schedule.

  This worker is responsible for:
  1. Loading active polling pipelines with intervals >= 60 seconds
  2. Executing the pipeline via Executor
  3. Scheduling the next run based on interval_seconds

  Pipelines with interval < 60s are handled by GenServer workers instead.
  """

  use Oban.Worker,
    queue: :pipelines,
    max_attempts: 3

  require Logger
  require Ash.Query
  alias Dash.Pipelines.{Pipeline, Executor}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"pipeline_id" => pipeline_id}}) do
    Logger.info("Executing polling worker for pipeline #{pipeline_id}")

    case load_pipeline(pipeline_id) do
      {:ok, pipeline} ->
        execute_and_reschedule(pipeline)

      {:error, reason} ->
        Logger.error("Failed to load pipeline #{pipeline_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Schedules a polling pipeline to run immediately or at a specific time.

  Options:
  - schedule_in: seconds to wait before running (defaults to interval_seconds)
  - schedule_at: specific DateTime to run at
  """
  def schedule(pipeline, opts \\ []) do
    schedule_in = Keyword.get(opts, :schedule_in, pipeline.interval_seconds)
    schedule_at = Keyword.get(opts, :schedule_at)

    job_args = %{
      "pipeline_id" => pipeline.id
    }

    job =
      cond do
        schedule_at ->
          new(job_args, scheduled_at: schedule_at)

        schedule_in && schedule_in > 0 ->
          new(job_args, schedule_in: schedule_in)

        true ->
          new(job_args)
      end

    Oban.insert(job)
  end

  defp load_pipeline(pipeline_id) do
    # Use authorize?: false since this runs as a system process
    Pipeline
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(id == ^pipeline_id and status == :active and type == :polling)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} ->
        {:error, "Pipeline not found or not active"}

      {:ok, pipeline} ->
        {:ok, pipeline}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_and_reschedule(pipeline) do
    # Execute the pipeline
    case Executor.execute(pipeline) do
      {:ok, _log} ->
        Logger.info("Pipeline #{pipeline.id} executed successfully")

        # Schedule next run if pipeline is still active
        schedule_next_run(pipeline)
        :ok

      {:error, reason} ->
        Logger.error("Pipeline #{pipeline.id} execution failed: #{inspect(reason)}")
        # Still schedule next run even on error
        schedule_next_run(pipeline)
        {:error, reason}
    end
  end

  defp schedule_next_run(pipeline) do
    # Check if pipeline is still active before scheduling
    case load_pipeline(pipeline.id) do
      {:ok, active_pipeline} ->
        schedule(active_pipeline, schedule_in: active_pipeline.interval_seconds)

        Logger.debug(
          "Scheduled next run for pipeline #{pipeline.id} in #{pipeline.interval_seconds}s"
        )

      {:error, _reason} ->
        Logger.info("Pipeline #{pipeline.id} is no longer active, not scheduling next run")
        :ok
    end
  end

  @doc """
  Cancels all scheduled and available jobs for a pipeline.

  This should be called when a pipeline is deactivated to prevent
  any pending jobs from executing.
  """
  def cancel_all(pipeline_id) do
    import Ecto.Query

    # Cancel all scheduled and available jobs for this pipeline
    {count, _} =
      Oban.Job
      |> where([j], j.queue == "pipelines")
      |> where([j], j.state in ["scheduled", "available", "retryable"])
      |> where([j], fragment("?->>'pipeline_id' = ?", j.args, ^pipeline_id))
      |> Dash.Repo.update_all(set: [state: "cancelled", cancelled_at: DateTime.utc_now()])

    Logger.info("Cancelled #{count} scheduled job(s) for pipeline #{pipeline_id}")
    {:ok, count}
  end
end
