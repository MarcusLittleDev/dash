defmodule Dash.Dashboards.WidgetTest do
  use Dash.DataCase, async: true

  alias Dash.Dashboards.Widget

  require Ash.Query

  setup do
    {org, owner} = create_organization_with_owner!()
    pipeline = create_pipeline!(organization: {org, owner})
    dashboard = create_dashboard!(organization: org, created_by: owner)

    %{org: org, owner: owner, pipeline: pipeline, dashboard: dashboard}
  end

  describe "create" do
    test "creates a table widget with valid attributes", ctx do
      assert {:ok, widget} =
               Widget
               |> Ash.Changeset.for_create(:create, %{
                 name: "Posts Table",
                 type: :table,
                 config: %{"columns" => []},
                 position: %{"x" => 0, "y" => 0, "w" => 6, "h" => 4},
                 dashboard_id: ctx.dashboard.id,
                 pipeline_id: ctx.pipeline.id
               })
               |> Ash.create(authorize?: false)

      assert widget.name == "Posts Table"
      assert widget.type == :table
      assert widget.dashboard_id == ctx.dashboard.id
      assert widget.pipeline_id == ctx.pipeline.id
    end

    test "creates a line chart widget", ctx do
      assert {:ok, widget} =
               Widget
               |> Ash.Changeset.for_create(:create, %{
                 name: "Trend Chart",
                 type: :line_chart,
                 config: %{"x_field" => "timestamp", "y_field" => "value"},
                 position: %{"x" => 6, "y" => 0, "w" => 6, "h" => 4},
                 dashboard_id: ctx.dashboard.id,
                 pipeline_id: ctx.pipeline.id
               })
               |> Ash.create(authorize?: false)

      assert widget.type == :line_chart
    end

    test "creates a stat card widget", ctx do
      assert {:ok, widget} =
               Widget
               |> Ash.Changeset.for_create(:create, %{
                 name: "Total Count",
                 type: :stat_card,
                 config: %{"field" => "count", "aggregation" => "sum"},
                 position: %{"x" => 0, "y" => 4, "w" => 3, "h" => 2},
                 dashboard_id: ctx.dashboard.id,
                 pipeline_id: ctx.pipeline.id
               })
               |> Ash.create(authorize?: false)

      assert widget.type == :stat_card
    end

    test "creates a bar chart widget", ctx do
      assert {:ok, widget} =
               Widget
               |> Ash.Changeset.for_create(:create, %{
                 name: "Distribution",
                 type: :bar_chart,
                 config: %{"x_field" => "category", "y_field" => "count"},
                 position: %{"x" => 3, "y" => 4, "w" => 3, "h" => 2},
                 dashboard_id: ctx.dashboard.id,
                 pipeline_id: ctx.pipeline.id
               })
               |> Ash.create(authorize?: false)

      assert widget.type == :bar_chart
    end

    test "rejects invalid widget type", ctx do
      assert {:error, _} =
               Widget
               |> Ash.Changeset.for_create(:create, %{
                 name: "Bad Widget",
                 type: :pie_chart,
                 config: %{},
                 position: %{"x" => 0, "y" => 0, "w" => 6, "h" => 4},
                 dashboard_id: ctx.dashboard.id,
                 pipeline_id: ctx.pipeline.id
               })
               |> Ash.create(authorize?: false)
    end

    test "requires name", ctx do
      assert {:error, _} =
               Widget
               |> Ash.Changeset.for_create(:create, %{
                 type: :table,
                 config: %{},
                 position: %{"x" => 0, "y" => 0, "w" => 6, "h" => 4},
                 dashboard_id: ctx.dashboard.id,
                 pipeline_id: ctx.pipeline.id
               })
               |> Ash.create(authorize?: false)
    end

    test "validates position has required keys", ctx do
      assert {:error, _} =
               Widget
               |> Ash.Changeset.for_create(:create, %{
                 name: "Bad Position",
                 type: :table,
                 config: %{},
                 position: %{"x" => 0, "y" => 0},
                 dashboard_id: ctx.dashboard.id,
                 pipeline_id: ctx.pipeline.id
               })
               |> Ash.create(authorize?: false)
    end

    test "uses default position when not specified", ctx do
      assert {:ok, widget} =
               Widget
               |> Ash.Changeset.for_create(:create, %{
                 name: "Default Position",
                 type: :table,
                 config: %{},
                 dashboard_id: ctx.dashboard.id,
                 pipeline_id: ctx.pipeline.id
               })
               |> Ash.create(authorize?: false)

      assert widget.position == %{"x" => 0, "y" => 0, "w" => 6, "h" => 4}
    end
  end

  describe "read policies" do
    test "org member can read widgets in their dashboard", ctx do
      widget = create_widget!(dashboard: ctx.dashboard, pipeline: ctx.pipeline, name: "Visible")

      assert {:ok, [found]} =
               Widget
               |> Ash.Query.filter(id == ^widget.id)
               |> Ash.read(actor: ctx.owner)

      assert found.id == widget.id
    end

    test "non-member cannot read widgets", ctx do
      widget = create_widget!(dashboard: ctx.dashboard, pipeline: ctx.pipeline)
      other_user = create_user!()

      assert {:ok, []} =
               Widget
               |> Ash.Query.filter(id == ^widget.id)
               |> Ash.read(actor: other_user)
    end
  end

  describe "update" do
    test "org member can update widget", ctx do
      widget = create_widget!(dashboard: ctx.dashboard, pipeline: ctx.pipeline, name: "Old Name")

      assert {:ok, updated} =
               widget
               |> Ash.Changeset.for_update(:update, %{name: "New Name"}, actor: ctx.owner)
               |> Ash.update()

      assert updated.name == "New Name"
    end

    test "can update widget position", ctx do
      widget = create_widget!(dashboard: ctx.dashboard, pipeline: ctx.pipeline)
      new_position = %{"x" => 3, "y" => 2, "w" => 9, "h" => 6}

      assert {:ok, updated} =
               widget
               |> Ash.Changeset.for_update(:update_position, %{position: new_position}, actor: ctx.owner)
               |> Ash.update()

      assert updated.position == new_position
    end

    test "non-member cannot update widget", ctx do
      widget = create_widget!(dashboard: ctx.dashboard, pipeline: ctx.pipeline)
      other_user = create_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               widget
               |> Ash.Changeset.for_update(:update, %{name: "Hacked"}, actor: other_user)
               |> Ash.update()
    end
  end

  describe "destroy" do
    test "org member can delete widget", ctx do
      widget = create_widget!(dashboard: ctx.dashboard, pipeline: ctx.pipeline)
      assert :ok = Ash.destroy(widget, actor: ctx.owner)
    end

    test "non-member cannot delete widget", ctx do
      widget = create_widget!(dashboard: ctx.dashboard, pipeline: ctx.pipeline)
      other_user = create_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.destroy(widget, actor: other_user)
    end
  end

  describe "for_dashboard action" do
    test "returns widgets for a specific dashboard", ctx do
      w1 = create_widget!(dashboard: ctx.dashboard, pipeline: ctx.pipeline, name: "Widget 1")
      w2 = create_widget!(dashboard: ctx.dashboard, pipeline: ctx.pipeline, name: "Widget 2")

      assert {:ok, widgets} =
               Widget
               |> Ash.Query.for_read(:for_dashboard, %{dashboard_id: ctx.dashboard.id})
               |> Ash.read(actor: ctx.owner)

      ids = Enum.map(widgets, & &1.id) |> MapSet.new()
      assert MapSet.member?(ids, w1.id)
      assert MapSet.member?(ids, w2.id)
      assert length(widgets) == 2
    end
  end

  describe "for_pipeline action" do
    test "returns widgets watching a specific pipeline", ctx do
      widget = create_widget!(dashboard: ctx.dashboard, pipeline: ctx.pipeline, name: "Pipeline Widget")

      assert {:ok, [found]} =
               Widget
               |> Ash.Query.for_read(:for_pipeline, %{pipeline_id: ctx.pipeline.id})
               |> Ash.read(actor: ctx.owner)

      assert found.id == widget.id
    end
  end
end
