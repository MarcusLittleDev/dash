defmodule Dash.Dashboards.DashboardTest do
  use Dash.DataCase, async: true

  alias Dash.Dashboards.Dashboard

  require Ash.Query

  describe "create" do
    test "creates a dashboard with valid attributes" do
      {org, owner} = create_organization_with_owner!()

      assert {:ok, dashboard} =
               Dashboard
               |> Ash.Changeset.for_create(:create, %{
                 name: "My Dashboard",
                 description: "Test dashboard",
                 organization_id: org.id,
                 created_by_id: owner.id
               })
               |> Ash.create(authorize?: false)

      assert dashboard.name == "My Dashboard"
      assert dashboard.description == "Test dashboard"
      assert dashboard.is_default == false
      assert dashboard.organization_id == org.id
      assert dashboard.created_by_id == owner.id
    end

    test "creates a default dashboard" do
      {org, _owner} = create_organization_with_owner!()

      assert {:ok, dashboard} =
               Dashboard
               |> Ash.Changeset.for_create(:create, %{
                 name: "Default",
                 is_default: true,
                 organization_id: org.id
               })
               |> Ash.create(authorize?: false)

      assert dashboard.is_default == true
    end

    test "requires name" do
      {org, _owner} = create_organization_with_owner!()

      assert {:error, _} =
               Dashboard
               |> Ash.Changeset.for_create(:create, %{organization_id: org.id})
               |> Ash.create(authorize?: false)
    end

    test "enforces unique name per organization" do
      {org, _owner} = create_organization_with_owner!()
      create_dashboard!(organization: org, name: "Unique Dashboard")

      assert {:error, _} =
               Dashboard
               |> Ash.Changeset.for_create(:create, %{
                 name: "Unique Dashboard",
                 organization_id: org.id
               })
               |> Ash.create(authorize?: false)
    end

    test "allows same name in different organizations" do
      {org1, _owner1} = create_organization_with_owner!()
      {org2, _owner2} = create_organization_with_owner!()

      create_dashboard!(organization: org1, name: "Shared Name")

      assert {:ok, _} =
               Dashboard
               |> Ash.Changeset.for_create(:create, %{
                 name: "Shared Name",
                 organization_id: org2.id
               })
               |> Ash.create(authorize?: false)
    end
  end

  describe "read policies" do
    test "org member can read dashboards in their organization" do
      {org, owner} = create_organization_with_owner!()
      dashboard = create_dashboard!(organization: org, name: "Visible")

      assert {:ok, [found]} =
               Dashboard
               |> Ash.Query.filter(id == ^dashboard.id)
               |> Ash.read(actor: owner)

      assert found.id == dashboard.id
    end

    test "non-member cannot read dashboards" do
      {org, _owner} = create_organization_with_owner!()
      dashboard = create_dashboard!(organization: org)
      other_user = create_user!()

      assert {:ok, []} =
               Dashboard
               |> Ash.Query.filter(id == ^dashboard.id)
               |> Ash.read(actor: other_user)
    end
  end

  describe "update" do
    test "org member can update dashboard" do
      {org, owner} = create_organization_with_owner!()
      dashboard = create_dashboard!(organization: org, name: "Old Name")

      assert {:ok, updated} =
               dashboard
               |> Ash.Changeset.for_update(:update, %{name: "New Name"}, actor: owner)
               |> Ash.update()

      assert updated.name == "New Name"
    end

    test "non-member cannot update dashboard" do
      {org, _owner} = create_organization_with_owner!()
      dashboard = create_dashboard!(organization: org)
      other_user = create_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               dashboard
               |> Ash.Changeset.for_update(:update, %{name: "Hacked"}, actor: other_user)
               |> Ash.update()
    end
  end

  describe "destroy" do
    test "org member can delete dashboard" do
      {org, owner} = create_organization_with_owner!()
      dashboard = create_dashboard!(organization: org)

      assert :ok = Ash.destroy(dashboard, actor: owner)
    end

    test "non-member cannot delete dashboard" do
      {org, _owner} = create_organization_with_owner!()
      dashboard = create_dashboard!(organization: org)
      other_user = create_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.destroy(dashboard, actor: other_user)
    end
  end

  describe "for_organization action" do
    test "returns dashboards for a specific organization" do
      {org, owner} = create_organization_with_owner!()
      {other_org, _} = create_organization_with_owner!()

      d1 = create_dashboard!(organization: org, name: "Dashboard 1")
      d2 = create_dashboard!(organization: org, name: "Dashboard 2")
      _d3 = create_dashboard!(organization: other_org, name: "Other Dashboard")

      assert {:ok, dashboards} =
               Dashboard
               |> Ash.Query.for_read(:for_organization, %{organization_id: org.id})
               |> Ash.read(actor: owner)

      ids = Enum.map(dashboards, & &1.id) |> MapSet.new()
      assert MapSet.member?(ids, d1.id)
      assert MapSet.member?(ids, d2.id)
      assert length(dashboards) == 2
    end
  end
end
