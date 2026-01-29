defmodule Dash.Accounts.TeamMemberTest do
  use Dash.DataCase, async: true

  alias Dash.Accounts.TeamMember

  require Ash.Query

  describe "create/1" do
    test "creates a team member with valid attributes" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      user = create_user!()
      create_org_membership!(organization: org, user: user, role: :member)

      assert {:ok, team_member} =
               TeamMember
               |> Ash.Changeset.for_create(:create, %{
                 team_id: team.id,
                 user_id: user.id,
                 role: :member
               })
               |> Ash.create(authorize?: false)

      assert team_member.team_id == team.id
      assert team_member.user_id == user.id
      assert team_member.role == :member
    end

    test "defaults role to :member" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      user = create_user!()

      assert {:ok, team_member} =
               TeamMember
               |> Ash.Changeset.for_create(:create, %{
                 team_id: team.id,
                 user_id: user.id
               })
               |> Ash.create(authorize?: false)

      assert team_member.role == :member
    end

    test "allows valid roles: owner, manager, member" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)

      for role <- [:manager, :member] do
        user = create_user!()

        assert {:ok, team_member} =
                 TeamMember
                 |> Ash.Changeset.for_create(:create, %{
                   team_id: team.id,
                   user_id: user.id,
                   role: role
                 })
                 |> Ash.create(authorize?: false)

        assert team_member.role == role
      end
    end

    test "enforces unique user per team" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      user = create_user!()
      create_team_member!(team: team, user: user, role: :member)

      assert {:error, _changeset} =
               TeamMember
               |> Ash.Changeset.for_create(:create, %{
                 team_id: team.id,
                 user_id: user.id,
                 role: :manager
               })
               |> Ash.create(authorize?: false)
    end
  end

  describe "create policies" do
    test "team owner can add members" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      new_user = create_user!()
      create_org_membership!(organization: org, user: new_user, role: :member)

      assert {:ok, team_member} =
               TeamMember
               |> Ash.Changeset.for_create(
                 :create,
                 %{team_id: team.id, user_id: new_user.id, role: :member},
                 actor: owner
               )
               |> Ash.create()

      assert team_member.role == :member
    end

    test "team owner can add managers" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      new_user = create_user!()
      create_org_membership!(organization: org, user: new_user, role: :member)

      assert {:ok, team_member} =
               TeamMember
               |> Ash.Changeset.for_create(
                 :create,
                 %{team_id: team.id, user_id: new_user.id, role: :manager},
                 actor: owner
               )
               |> Ash.create()

      assert team_member.role == :manager
    end

    test "team owner cannot add another owner" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      new_user = create_user!()
      create_org_membership!(organization: org, user: new_user, role: :member)

      assert {:error, %Ash.Error.Forbidden{}} =
               TeamMember
               |> Ash.Changeset.for_create(
                 :create,
                 %{team_id: team.id, user_id: new_user.id, role: :owner},
                 actor: owner
               )
               |> Ash.create()
    end

    test "team manager can add members" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      manager = create_user!()
      create_org_membership!(organization: org, user: manager, role: :member)
      create_team_member!(team: team, user: manager, role: :manager)

      new_user = create_user!()
      create_org_membership!(organization: org, user: new_user, role: :member)

      assert {:ok, team_member} =
               TeamMember
               |> Ash.Changeset.for_create(
                 :create,
                 %{team_id: team.id, user_id: new_user.id, role: :member},
                 actor: manager
               )
               |> Ash.create()

      assert team_member.role == :member
    end

    test "team manager cannot add managers" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      manager = create_user!()
      create_org_membership!(organization: org, user: manager, role: :member)
      create_team_member!(team: team, user: manager, role: :manager)

      new_user = create_user!()
      create_org_membership!(organization: org, user: new_user, role: :member)

      assert {:error, %Ash.Error.Forbidden{}} =
               TeamMember
               |> Ash.Changeset.for_create(
                 :create,
                 %{team_id: team.id, user_id: new_user.id, role: :manager},
                 actor: manager
               )
               |> Ash.create()
    end

    test "regular team member cannot add members" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      member = create_user!()
      create_org_membership!(organization: org, user: member, role: :member)
      create_team_member!(team: team, user: member, role: :member)

      new_user = create_user!()
      create_org_membership!(organization: org, user: new_user, role: :member)

      assert {:error, %Ash.Error.Forbidden{}} =
               TeamMember
               |> Ash.Changeset.for_create(
                 :create,
                 %{team_id: team.id, user_id: new_user.id, role: :member},
                 actor: member
               )
               |> Ash.create()
    end
  end

  describe "read policies" do
    test "org member can read team members" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      org_member = create_user!()
      create_org_membership!(organization: org, user: org_member, role: :member)

      assert {:ok, team_members} =
               TeamMember
               |> Ash.Query.filter(team_id == ^team.id)
               |> Ash.read(actor: org_member)

      # Should see the team owner
      assert length(team_members) == 1
    end

    test "non-org member cannot read team members" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      outsider = create_user!()

      assert {:ok, []} =
               TeamMember
               |> Ash.Query.filter(team_id == ^team.id)
               |> Ash.read(actor: outsider)
    end
  end

  describe "destroy policies" do
    test "team owner can remove members" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      member = create_user!()
      create_org_membership!(organization: org, user: member, role: :member)
      membership = create_team_member!(team: team, user: member, role: :member)

      assert :ok =
               membership
               |> Ash.Changeset.for_destroy(:destroy, %{}, actor: owner)
               |> Ash.destroy()
    end

    test "team owner can remove managers" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      manager = create_user!()
      create_org_membership!(organization: org, user: manager, role: :member)
      membership = create_team_member!(team: team, user: manager, role: :manager)

      assert :ok =
               membership
               |> Ash.Changeset.for_destroy(:destroy, %{}, actor: owner)
               |> Ash.destroy()
    end

    test "team owner cannot remove themselves" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)

      # Get owner's team membership
      {:ok, [owner_membership]} =
        TeamMember
        |> Ash.Query.filter(team_id == ^team.id and user_id == ^owner.id)
        |> Ash.read(authorize?: false)

      assert {:error, %Ash.Error.Forbidden{}} =
               owner_membership
               |> Ash.Changeset.for_destroy(:destroy, %{}, actor: owner)
               |> Ash.destroy()
    end

    test "team manager can remove regular members" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      manager = create_user!()
      create_org_membership!(organization: org, user: manager, role: :member)
      create_team_member!(team: team, user: manager, role: :manager)

      member = create_user!()
      create_org_membership!(organization: org, user: member, role: :member)
      membership = create_team_member!(team: team, user: member, role: :member)

      assert :ok =
               membership
               |> Ash.Changeset.for_destroy(:destroy, %{}, actor: manager)
               |> Ash.destroy()
    end

    test "team manager cannot remove other managers" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      manager1 = create_user!()
      create_org_membership!(organization: org, user: manager1, role: :member)
      create_team_member!(team: team, user: manager1, role: :manager)

      manager2 = create_user!()
      create_org_membership!(organization: org, user: manager2, role: :member)
      membership2 = create_team_member!(team: team, user: manager2, role: :manager)

      assert {:error, %Ash.Error.Forbidden{}} =
               membership2
               |> Ash.Changeset.for_destroy(:destroy, %{}, actor: manager1)
               |> Ash.destroy()
    end

    test "regular member cannot remove anyone" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      member1 = create_user!()
      create_org_membership!(organization: org, user: member1, role: :member)
      create_team_member!(team: team, user: member1, role: :member)

      member2 = create_user!()
      create_org_membership!(organization: org, user: member2, role: :member)
      membership2 = create_team_member!(team: team, user: member2, role: :member)

      assert {:error, %Ash.Error.Forbidden{}} =
               membership2
               |> Ash.Changeset.for_destroy(:destroy, %{}, actor: member1)
               |> Ash.destroy()
    end
  end

  describe "update_role policies" do
    test "team owner can update member roles" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      member = create_user!()
      create_org_membership!(organization: org, user: member, role: :member)
      membership = create_team_member!(team: team, user: member, role: :member)

      assert {:ok, updated} =
               membership
               |> Ash.Changeset.for_update(:update_role, %{role: :manager}, actor: owner)
               |> Ash.update()

      assert updated.role == :manager
    end

    test "team manager cannot update roles" do
      {org, owner} = create_organization_with_owner!()
      team = create_team!(organization: org, actor: owner)
      manager = create_user!()
      create_org_membership!(organization: org, user: manager, role: :member)
      create_team_member!(team: team, user: manager, role: :manager)

      member = create_user!()
      create_org_membership!(organization: org, user: member, role: :member)
      membership = create_team_member!(team: team, user: member, role: :member)

      assert {:error, %Ash.Error.Forbidden{}} =
               membership
               |> Ash.Changeset.for_update(:update_role, %{role: :manager}, actor: manager)
               |> Ash.update()
    end
  end
end
