defmodule Dash.Pipelines.Workers.PollingWorkerTest do
  use Dash.DataCase, async: true
  use Oban.Testing, repo: Dash.Repo

  import Mox
  import Dash.Factory

  require Ash.Query
  alias Dash.Pipelines.{Pipeline, ExecutionLog}
  alias Dash.Pipelines.Workers.PollingWorker

  setup :verify_on_exit!

  describe "perform/1 - job execution" do
    setup do
      {org, _owner} = create_organization_with_owner!()

      pipeline =
        create_pipeline!(
          organization: {org, _owner},
          type: :polling,
          status: :active,
          interval_seconds: 300,
          source_config: %{"url" => "https://api.example.com/data"}
        )

      create_data_mapping!(pipeline: pipeline)

      %{pipeline: pipeline}
    end

    test "executes pipeline successfully", %{pipeline: pipeline} do
      # Mock HTTP adapter
      expect(Dash.Adapters.ExternalMock, :fetch, fn _source_type, _config ->
        {:ok, [%{"title" => "Post", "body" => "Content"}], %{response_time_ms: 100}}
      end)

      # Perform the job
      assert :ok = perform_job(PollingWorker, %{"pipeline_id" => pipeline.id})

      # Verify execution log created
      logs =
        ExecutionLog
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(pipeline_id == ^pipeline.id)
        |> Ash.read!(authorize?: false)

      assert length(logs) == 1
      assert hd(logs).status == :success
    end

    test "returns error when pipeline not found" do
      fake_id = Ash.UUID.generate()

      assert {:error, reason} = perform_job(PollingWorker, %{"pipeline_id" => fake_id})
      assert reason =~ "not found" or reason =~ "not active"
    end

    test "returns error when pipeline is inactive", %{pipeline: pipeline} do
      # Deactivate pipeline
      pipeline
      |> Ash.Changeset.for_update(:update, %{status: :inactive})
      |> Ash.update!(authorize?: false)

      assert {:error, reason} = perform_job(PollingWorker, %{"pipeline_id" => pipeline.id})
      assert reason =~ "not found" or reason =~ "not active"
    end

    test "returns error when pipeline is wrong type" do
      # Create a webhook pipeline directly
      {org, _owner} = create_organization_with_owner!()
      webhook_pipeline = create_pipeline!(
        organization: {org, _owner},
        type: :webhook,
        status: :active,
        interval_seconds: nil
      )

      assert {:error, reason} = perform_job(PollingWorker, %{"pipeline_id" => webhook_pipeline.id})
      assert reason =~ "not found" or reason =~ "not active"
    end
  end

  describe "schedule/2 - job scheduling" do
    setup do
      {org, _owner} = create_organization_with_owner!()

      pipeline =
        create_pipeline!(
          organization: {org, _owner},
          type: :polling,
          status: :active,
          interval_seconds: 300
        )

      %{pipeline: pipeline}
    end

    test "schedules job with default interval", %{pipeline: pipeline} do
      assert {:ok, job} = PollingWorker.schedule(pipeline)

      assert job.args == %{"pipeline_id" => pipeline.id}
      assert job.queue == "pipelines"
      assert job.worker == "Dash.Pipelines.Workers.PollingWorker"

      # Job should be scheduled ~300 seconds from now
      scheduled_in = DateTime.diff(job.scheduled_at, DateTime.utc_now(), :second)
      assert scheduled_in >= 295 and scheduled_in <= 305
    end

    test "schedules job with custom schedule_in", %{pipeline: pipeline} do
      assert {:ok, job} = PollingWorker.schedule(pipeline, schedule_in: 60)

      # Job should be scheduled ~60 seconds from now
      scheduled_in = DateTime.diff(job.scheduled_at, DateTime.utc_now(), :second)
      assert scheduled_in >= 55 and scheduled_in <= 65
    end

    test "schedules job immediately when schedule_in is 0", %{pipeline: pipeline} do
      assert {:ok, job} = PollingWorker.schedule(pipeline, schedule_in: 0)

      # Job should be available immediately (scheduled_at is nil or very close to now)
      if job.scheduled_at do
        scheduled_in = DateTime.diff(job.scheduled_at, DateTime.utc_now(), :second)
        assert scheduled_in >= -5 and scheduled_in <= 5
      else
        # When schedule_in is 0 with no delay, job runs immediately
        assert job.state in ["available", "scheduled"]
      end
    end

    test "schedules job at specific time", %{pipeline: pipeline} do
      future_time = DateTime.add(DateTime.utc_now(), 600, :second)

      assert {:ok, job} = PollingWorker.schedule(pipeline, schedule_at: future_time)

      # Job should be scheduled at the specified time
      assert DateTime.compare(job.scheduled_at, future_time) == :eq
    end
  end

  describe "perform/1 - rescheduling logic" do
    setup do
      {org, _owner} = create_organization_with_owner!()

      pipeline =
        create_pipeline!(
          organization: {org, _owner},
          type: :polling,
          status: :active,
          interval_seconds: 120,
          source_config: %{"url" => "https://api.example.com/data"}
        )

      create_data_mapping!(pipeline: pipeline)

      %{pipeline: pipeline}
    end

    test "schedules next run after successful execution", %{pipeline: pipeline} do
      # Mock successful execution
      expect(Dash.Adapters.ExternalMock, :fetch, fn _source_type, _config ->
        {:ok, [], %{response_time_ms: 100}}
      end)

      # Perform the job
      assert :ok = perform_job(PollingWorker, %{"pipeline_id" => pipeline.id})

      # Verify next job was scheduled
      jobs = all_enqueued(worker: PollingWorker)
      assert length(jobs) == 1

      next_job = hd(jobs)
      assert next_job.args["pipeline_id"] == pipeline.id

      # Should be scheduled ~120 seconds from now
      scheduled_in = DateTime.diff(next_job.scheduled_at, DateTime.utc_now(), :second)
      assert scheduled_in >= 115 and scheduled_in <= 125
    end

    test "schedules next run even after execution error", %{pipeline: pipeline} do
      # Mock failed execution
      expect(Dash.Adapters.ExternalMock, :fetch, fn _source_type, _config ->
        {:error, "API error"}
      end)

      # Perform the job (will fail but still reschedule)
      perform_job(PollingWorker, %{"pipeline_id" => pipeline.id})

      # Verify next job was scheduled
      jobs = all_enqueued(worker: PollingWorker)
      assert length(jobs) == 1
    end

    test "does not schedule next run if pipeline is deactivated", %{pipeline: pipeline} do
      # Mock execution but deactivate pipeline before it completes
      expect(Dash.Adapters.ExternalMock, :fetch, fn _source_type, _config ->
        # Deactivate pipeline during execution
        Pipeline
        |> Ash.get!(pipeline.id, authorize?: false)
        |> Ash.Changeset.for_update(:update, %{status: :inactive})
        |> Ash.update!(authorize?: false)

        {:ok, [], %{response_time_ms: 100}}
      end)

      # Perform the job
      assert :ok = perform_job(PollingWorker, %{"pipeline_id" => pipeline.id})

      # Verify NO next job was scheduled (pipeline is inactive)
      jobs = all_enqueued(worker: PollingWorker)
      assert length(jobs) == 0
    end
  end

  describe "Oban worker configuration" do
    test "is configured with correct queue" do
      # Verify worker configuration by checking a scheduled job
      {org, _owner} = create_organization_with_owner!()
      pipeline = create_pipeline!(organization: {org, _owner}, type: :polling, status: :active, interval_seconds: 60)

      {:ok, job} = PollingWorker.schedule(pipeline)
      assert job.queue == "pipelines"
    end
  end
end
