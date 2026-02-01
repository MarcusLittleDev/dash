defmodule Dash.Pipelines.ExecutorTest do
  use Dash.DataCase, async: true

  import Mox
  import Dash.Factory

  require Ash.Query
  alias Dash.Pipelines.{Executor, Pipeline, ExecutionLog, PipelineEvent}

  setup :verify_on_exit!

  describe "execute/1 - happy path" do
    setup do
      # Create organization and pipeline
      {org, owner} = create_organization_with_owner!()

      pipeline =
        create_pipeline!(
          organization: {org, owner},
          type: :polling,
          status: :active,
          interval_seconds: 300,
          persist_data: true,
          source_config: %{
            "url" => "https://api.example.com/data",
            "method" => "GET"
          }
        )

      # Create data mapping
      create_data_mapping!(
        pipeline: pipeline,
        mappings: [
          %{
            source_field: "title",
            target_field: "title",
            required: true,
            transformation_type: "direct"
          },
          %{
            source_field: "body",
            target_field: "content",
            required: false,
            transformation_type: "direct"
          }
        ]
      )

      %{pipeline: pipeline, organization: org}
    end

    test "executes pipeline successfully with data", %{pipeline: pipeline} do
      # Mock HTTP adapter to return data
      expect(Dash.Adapters.ExternalMock, :fetch, fn _source_type, _config ->
        data = [
          %{"id" => 1, "title" => "Post 1", "body" => "Content 1"},
          %{"id" => 2, "title" => "Post 2", "body" => "Content 2"}
        ]

        metadata = %{response_time_ms: 150}
        {:ok, data, metadata}
      end)

      # Execute pipeline
      assert {:ok, log} = Executor.execute(pipeline)
      assert log.records_fetched == 2
      assert log.records_stored == 2
      assert log.status == :success

      # Verify ExecutionLog was created
      logs =
        ExecutionLog
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(pipeline_id == ^pipeline.id)
        |> Ash.read!(authorize?: false)

      assert length(logs) == 1
      db_log = hd(logs)
      assert db_log.status == :success
      assert db_log.records_fetched == 2
      assert db_log.records_stored == 2
      assert db_log.source_response_time_ms == 150
      assert db_log.duration_ms > 0
      assert is_nil(db_log.error_type)
      assert is_nil(db_log.error_message)

      # Verify PipelineEvents were created
      events =
        PipelineEvent
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(pipeline_id == ^pipeline.id)
        |> Ash.read!(authorize?: false)

      assert length(events) == 2

      # Verify data transformation
      first_event = hd(events)
      assert first_event.data["title"] in ["Post 1", "Post 2"]
      assert first_event.data["content"] in ["Content 1", "Content 2"]
    end

    test "handles empty response (no new data)", %{pipeline: pipeline} do
      # Mock HTTP adapter to return empty list
      expect(Dash.Adapters.ExternalMock, :fetch, fn _source_type, _config ->
        {:ok, [], %{response_time_ms: 100}}
      end)

      # Execute pipeline
      assert {:ok, log} = Executor.execute(pipeline)
      assert log.records_fetched == 0
      assert log.records_stored == 0
      assert log.status == :no_data

      # Verify ExecutionLog was created (even with no data)
      logs =
        ExecutionLog
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(pipeline_id == ^pipeline.id)
        |> Ash.read!(authorize?: false)

      assert length(logs) == 1
      db_log = hd(logs)
      assert db_log.status == :no_data
      assert db_log.records_fetched == 0
      assert db_log.records_stored == 0

      # Verify NO PipelineEvents were created
      events =
        PipelineEvent
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(pipeline_id == ^pipeline.id)
        |> Ash.read!(authorize?: false)

      assert length(events) == 0
    end

    test "skips storage when persist_data is false", %{pipeline: pipeline} do
      # Update pipeline to not persist data
      pipeline =
        pipeline
        |> Ash.Changeset.for_update(:update, %{persist_data: false})
        |> Ash.update!(authorize?: false)

      # Mock HTTP adapter
      expect(Dash.Adapters.ExternalMock, :fetch, fn _source_type, _config ->
        {:ok, [%{"title" => "Post", "body" => "Content"}], %{response_time_ms: 100}}
      end)

      # Execute pipeline
      assert {:ok, log} = Executor.execute(pipeline)
      assert log.records_fetched == 1
      assert log.records_stored == 0
      assert log.status == :success

      # Verify ExecutionLog was created
      logs =
        ExecutionLog
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(pipeline_id == ^pipeline.id)
        |> Ash.read!(authorize?: false)

      assert length(logs) == 1

      # Verify NO PipelineEvents were created (persist_data = false)
      events =
        PipelineEvent
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(pipeline_id == ^pipeline.id)
        |> Ash.read!(authorize?: false)

      assert length(events) == 0
    end
  end

  describe "execute/1 - error handling" do
    setup do
      {org, owner} = create_organization_with_owner!()

      pipeline =
        create_pipeline!(
          organization: {org, owner},
          type: :polling,
          status: :active,
          interval_seconds: 300,
          source_config: %{"url" => "https://api.example.com/data"}
        )

      create_data_mapping!(pipeline: pipeline)

      %{pipeline: pipeline}
    end

    test "handles source fetch error", %{pipeline: pipeline} do
      # Mock HTTP adapter to fail
      expect(Dash.Adapters.ExternalMock, :fetch, fn _source_type, _config ->
        {:error, "Connection timeout"}
      end)

      # Execute pipeline
      assert {:ok, log} = Executor.execute(pipeline)
      assert log.status == :error

      # Verify ExecutionLog with error
      logs =
        ExecutionLog
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(pipeline_id == ^pipeline.id)
        |> Ash.read!(authorize?: false)

      assert length(logs) == 1
      db_log = hd(logs)
      assert db_log.status == :error
      assert db_log.error_type == :source_fetch
      assert db_log.error_message =~ "Connection timeout"
    end

    test "handles transformation error (missing required field)", %{pipeline: pipeline} do
      # Update mapping to require a field that won't exist
      mapping = Ash.load!(pipeline, :data_mappings, authorize?: false).data_mappings |> hd()

      mapping
      |> Ash.Changeset.for_update(:update, %{
        source_field: "nonexistent_field",
        target_field: "target",
        required: true,
        transformation_type: "direct"
      })
      |> Ash.update!(authorize?: false)

      # Mock HTTP adapter
      expect(Dash.Adapters.ExternalMock, :fetch, fn _source_type, _config ->
        {:ok, [%{"title" => "Post"}], %{response_time_ms: 100}}
      end)

      # Execute pipeline
      assert {:ok, log} = Executor.execute(pipeline)
      assert log.status == :error

      # Verify ExecutionLog with error
      logs =
        ExecutionLog
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(pipeline_id == ^pipeline.id)
        |> Ash.read!(authorize?: false)

      assert length(logs) == 1
      db_log = hd(logs)
      assert db_log.status == :error
      assert db_log.error_type == :transformation
      # Note: records_fetched remains at default (0) in error path
    end
  end

  describe "execute/1 - metrics and logging" do
    setup do
      {org, owner} = create_organization_with_owner!()

      pipeline =
        create_pipeline!(
          organization: {org, owner},
          type: :polling,
          status: :active,
          source_config: %{"url" => "https://api.example.com/data"}
        )

      create_data_mapping!(pipeline: pipeline)

      %{pipeline: pipeline}
    end

    test "records execution duration", %{pipeline: pipeline} do
      expect(Dash.Adapters.ExternalMock, :fetch, fn _source_type, _config ->
        # Simulate some processing time
        Process.sleep(10)
        {:ok, [%{"title" => "Post", "body" => "Content"}], %{response_time_ms: 50}}
      end)

      assert {:ok, log} = Executor.execute(pipeline)

      assert log.duration_ms >= 10
      assert log.source_response_time_ms == 50
    end

    test "tracks source response time separately", %{pipeline: pipeline} do
      expect(Dash.Adapters.ExternalMock, :fetch, fn _source_type, _config ->
        {:ok, [], %{response_time_ms: 250}}
      end)

      assert {:ok, log} = Executor.execute(pipeline)

      assert log.source_response_time_ms == 250
    end
  end
end
