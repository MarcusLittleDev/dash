defmodule Dash.Accounts.TeamTest do
  use Dash.DataCase, async: true

  alias Dash.Accounts.{Team, TeamMember}

  require Ash.Query

  describe "create/1" do
    test "creates a team with valid attributes" do
      {org, owner} = create_organization_with_owner!()

      assert {:ok, team} =
               Team
               |> Ash.Changeset.for_create(
                 :create,
                 %{name: "Engineering", organization_id: org.id},
                 actor: owner
               )
               |> Ash.create()

      assert team.name == "Engineering"
      assert team.slug == "engineering"
      assert team.organization_id == org.id
    end

    test "auto-generates slug from name" do
      {org, owner} = create_organization_with_owner!()

      assert {:ok, team} =
               Team
               |> Ash.Changeset.for_create(
                 :create,
                 %{name: "Product Design Team", organization_id: org.id},
                 actor: owner
               )
               |> Ash.create()

      assert team.slug == "product-design-team"
    end

    test "auto-adds creator as team owner" do
      {org, owner} = create_organization_with_owner!()

      assert {:ok, team} =
               Team
               |> Ash.Changeset.for_create(
                 :create,
                 %{name: "New Team", organization_id: org.id},
                 actor: owner
               )
               |> Ash.create()

      # Check that owner membership was created
      {:ok, [membership]} =
        TeamMember
        |> Ash.Query.filter(team_id == ^team.id and user_id == ^owner.id)
        |> Ash.read(authorize?: false)

      assert membership.role == :owner
    end

    test "requires name" do
      {org, owner} = create_organization_with_owner!()

      assert {:error, changeset} =
               Team
               |> Ash.Changeset.for_create(
                 :create,
                 %{organization_id: org.id},
                 actor: owner
               )
               |> Ash.create()

      assert has_error?(changeset, :name)
    end

    test "allows optional description" do
      {org, owner} = create_organization_with_owner!()

      assert {:ok, team} =
               Team
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Support",
                   description: "Customer support team",
                   organization_id: org.id
                 },
                 actor: owner
               )
               |> Ash.create()

      assert team.description == "Customer support team"
    end

    test "enforces unique slug per organization" do
      {org, owner} = create_organization_with_owner!()
      create_team!(organization: org, actor: owner, name: "Engineering")

      assert {:error, _changeset} =
               Team
               |> Ash.Changeset.for_create(
                 :create,
                 %{name: "Engineering", organization_id: org.id},
                 actor: owner
               )
               |> Ash.create()
    end

    test "allows same team name in different organizations" do
      {org1, owner1} = create_organization_with_owner!()
      {org2, owner2} = create_organization_with_owner!()

      assert {:ok, team1} =
               Team
               |> Ash.Changeset.for_create(
                 :create,
                 %{name: "Engineering", organization_id: org1.id},
                 actor: owner1
               )
               |> Ash.create()

      assert {:ok, team2} =
               Team
               |> Ash.Changeset.for_create(
                 :create,
                 %{name: "Engineering", organization_id: org2.id},
                 actor: owner2
               )
               |> Ash.create()

      assert team1.slug == "engineering"
      assert team2.slug == "engineering"
      assert team1.organization_id != team2.organization_id
    end
  end

  describe "create policies" do
    test "org member can create teams" do
      {org, _owner} = create_organization_with_owner!()
      member = create_user!()
      create_org_membership!(organization: org, user: member, role: :member)

      assert {:ok, _team} =
               Team
               |> Ash.Changeset.for_create(
                 :create,
                 %{name: "New Team", organization_id: org.id},
                 actor: member
               )
               |> Ash.create()
    end

    test "non-member cannot create teams" do
      {org, _owner} = create_organization_with_owner!()
      outsider = create_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               Team
               |> Ash.Changeset.for_create(
                 :create,
                 %{name: "Unauthorized Team", organization_id: org.id},
                 actor: outsider
               )
               |> Ash.create()
    end
  end

  describe "read policies" do
    test "org members can read teams in their organization" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      member = create_user!()
      create_org_membership!(organization: org, user: member, role: :member)

      assert {:ok, [found_team]} =
               Team
               |> Ash.Query.filter(id == ^team.id)
               |> Ash.read(actor: member)

      assert found_team.id == team.id
    end

    test "non-members cannot read teams" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      outsider = create_user!()

      assert {:ok, []} =
               Team
               |> Ash.Query.filter(id == ^team.id)
               |> Ash.read(actor: outsider)
    end
  end

  describe "update policies" do
    test "team owner can update team" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)

      assert {:ok, updated_team} =
               team
               |> Ash.Changeset.for_update(
                 :update,
                 %{name: "Renamed Team", description: "New description"},
                 actor: owner
               )
               |> Ash.update()

      assert updated_team.name == "Renamed Team"
      assert updated_team.description == "New description"
    end

    test "org owner can update any team" do
      {org, org_owner} = create_organization_with_owner!()
      team_creator = create_user!()
      create_org_membership!(organization: org, user: team_creator, role: :member)
      team = create_team!(organization: org, actor: team_creator)

      assert {:ok, updated_team} =
               team
               |> Ash.Changeset.for_update(
                 :update,
                 %{name: "Org Owner Updated"},
                 actor: org_owner
               )
               |> Ash.update()

      assert updated_team.name == "Org Owner Updated"
    end

    test "org admin can update any team" do
      {org, _owner} = create_organization_with_owner!()
      admin = create_user!()
      create_org_membership!(organization: org, user: admin, role: :admin)
      team_creator = create_user!()
      create_org_membership!(organization: org, user: team_creator, role: :member)
      team = create_team!(organization: org, actor: team_creator)

      assert {:ok, updated_team} =
               team
               |> Ash.Changeset.for_update(
                 :update,
                 %{name: "Admin Updated"},
                 actor: admin
               )
               |> Ash.update()

      assert updated_team.name == "Admin Updated"
    end

    test "regular org member cannot update team they don't own" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      member = create_user!()
      create_org_membership!(organization: org, user: member, role: :member)

      assert {:error, %Ash.Error.Forbidden{}} =
               team
               |> Ash.Changeset.for_update(
                 :update,
                 %{name: "Unauthorized Update"},
                 actor: member
               )
               |> Ash.update()
    end
  end

  describe "destroy policies" do
    test "team owner can delete team" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)

      assert :ok =
               team
               |> Ash.Changeset.for_destroy(:destroy, %{}, actor: owner)
               |> Ash.destroy()
    end

    test "org owner can delete any team" do
      {org, org_owner} = create_organization_with_owner!()
      team_creator = create_user!()
      create_org_membership!(organization: org, user: team_creator, role: :member)
      team = create_team!(organization: org, actor: team_creator)

      assert :ok =
               team
               |> Ash.Changeset.for_destroy(:destroy, %{}, actor: org_owner)
               |> Ash.destroy()
    end

    test "regular member cannot delete team they don't own" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      member = create_user!()
      create_org_membership!(organization: org, user: member, role: :member)

      assert {:error, %Ash.Error.Forbidden{}} =
               team
               |> Ash.Changeset.for_destroy(:destroy, %{}, actor: member)
               |> Ash.destroy()
    end
  end

  # Helper functions

  defp has_error?(%Ash.Changeset{} = changeset, field) do
    Enum.any?(changeset.errors, fn error ->
      error.field == field
    end)
  end

  defp has_error?(%Ash.Error.Invalid{} = error, field) do
    Enum.any?(error.errors, fn err ->
      err.field == field
    end)
  end
end
