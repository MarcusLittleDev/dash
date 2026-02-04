defmodule Dash.Dashboards.DataServerTest do
  use Dash.DataCase, async: false

  alias Dash.Dashboards.DataServer

  setup do
    # DataServer is already started in the supervision tree
    # Clear any existing data between tests
    widget_id = Ecto.UUID.generate()
    %{widget_id: widget_id}
  end

  describe "get_data/2" do
    test "returns empty list for unknown widget", ctx do
      assert DataServer.get_data(ctx.widget_id) == []
    end

    test "returns cached data for a widget", ctx do
      records = [%{"a" => 1}, %{"a" => 2}, %{"a" => 3}]
      DataServer.push_data(ctx.widget_id, records)
      # Give the GenServer time to process the cast
      Process.sleep(50)

      result = DataServer.get_data(ctx.widget_id)
      assert length(result) == 3
      assert Enum.at(result, 0) == %{"a" => 1}
    end

    test "respects limit option", ctx do
      records = Enum.map(1..10, fn i -> %{"val" => i} end)
      DataServer.push_data(ctx.widget_id, records)
      Process.sleep(50)

      result = DataServer.get_data(ctx.widget_id, limit: 3)
      assert length(result) == 3
    end

    test "default limit is 100", ctx do
      records = Enum.map(1..150, fn i -> %{"val" => i} end)
      DataServer.push_data(ctx.widget_id, records)
      Process.sleep(50)

      result = DataServer.get_data(ctx.widget_id)
      assert length(result) == 100
    end
  end

  describe "push_data/2" do
    test "prepends new records to existing data", ctx do
      DataServer.push_data(ctx.widget_id, [%{"val" => "old"}])
      Process.sleep(50)
      DataServer.push_data(ctx.widget_id, [%{"val" => "new"}])
      Process.sleep(50)

      result = DataServer.get_data(ctx.widget_id)
      assert Enum.at(result, 0) == %{"val" => "new"}
      assert Enum.at(result, 1) == %{"val" => "old"}
    end

    test "trims to max 1000 records", ctx do
      # Push 600, then push 600 more
      batch1 = Enum.map(1..600, fn i -> %{"val" => i} end)
      DataServer.push_data(ctx.widget_id, batch1)
      Process.sleep(50)

      batch2 = Enum.map(601..1200, fn i -> %{"val" => i} end)
      DataServer.push_data(ctx.widget_id, batch2)
      Process.sleep(50)

      count = DataServer.get_count(ctx.widget_id)
      assert count == 1000
    end
  end

  describe "clear_data/1" do
    test "removes all data for a widget", ctx do
      DataServer.push_data(ctx.widget_id, [%{"val" => 1}])
      Process.sleep(50)
      assert DataServer.get_count(ctx.widget_id) == 1

      DataServer.clear_data(ctx.widget_id)
      Process.sleep(50)
      assert DataServer.get_data(ctx.widget_id) == []
    end
  end

  describe "get_count/1" do
    test "returns 0 for unknown widget" do
      assert DataServer.get_count(Ecto.UUID.generate()) == 0
    end

    test "returns count of cached records", ctx do
      records = Enum.map(1..5, fn i -> %{"val" => i} end)
      DataServer.push_data(ctx.widget_id, records)
      Process.sleep(50)

      assert DataServer.get_count(ctx.widget_id) == 5
    end
  end

  describe "clear_pipeline_data/1" do
    test "clears data for all widgets of a pipeline" do
      {org, owner} = create_organization_with_owner!()
      pipeline = create_pipeline!(organization: {org, owner})
      dashboard = create_dashboard!(organization: org, created_by: owner)

      w1 = create_widget!(dashboard: dashboard, pipeline: pipeline, name: "W1")
      w2 = create_widget!(dashboard: dashboard, pipeline: pipeline, name: "W2")

      DataServer.push_data(w1.id, [%{"val" => 1}])
      DataServer.push_data(w2.id, [%{"val" => 2}])
      Process.sleep(50)

      assert DataServer.get_count(w1.id) == 1
      assert DataServer.get_count(w2.id) == 1

      DataServer.clear_pipeline_data(pipeline.id)
      Process.sleep(100)

      assert DataServer.get_data(w1.id) == []
      assert DataServer.get_data(w2.id) == []
    end
  end
end
