defmodule Dash.Accounts.OrgMembershipTest do
  use Dash.DataCase, async: true

  alias Dash.Accounts.OrgMembership

  require Ash.Query

  # Helper to create membership using manage_relationship (since organization_id/user_id
  # aren't directly accepted by the create action)
  defp create_membership(org, user, role, opts \\ []) do
    OrgMembership
    |> Ash.Changeset.for_create(:create, %{role: role})
    |> Ash.Changeset.manage_relationship(:organization, org, type: :append)
    |> Ash.Changeset.manage_relationship(:user, user, type: :append)
    |> Ash.create(opts)
  end

  describe "create/1" do
    test "creates a membership with valid attributes" do
      org = create_organization!()
      user = create_user!()

      assert {:ok, membership} = create_membership(org, user, :member, authorize?: false)

      assert membership.organization_id == org.id
      assert membership.user_id == user.id
      assert membership.role == :member
    end

    test "defaults role to :member" do
      org = create_organization!()
      user = create_user!()

      assert {:ok, membership} =
               OrgMembership
               |> Ash.Changeset.for_create(:create, %{})
               |> Ash.Changeset.manage_relationship(:organization, org, type: :append)
               |> Ash.Changeset.manage_relationship(:user, user, type: :append)
               |> Ash.create(authorize?: false)

      assert membership.role == :member
    end

    test "allows valid roles: owner, admin, member" do
      org = create_organization!()

      for role <- [:owner, :admin, :member] do
        user = create_user!()
        assert {:ok, membership} = create_membership(org, user, role, authorize?: false)
        assert membership.role == role
      end
    end

    test "enforces unique user per organization" do
      org = create_organization!()
      user = create_user!()
      create_org_membership!(organization: org, user: user, role: :member)

      assert {:error, _changeset} = create_membership(org, user, :admin, authorize?: false)
    end
  end

  describe "create policies" do
    test "owner can add members to their organization" do
      {org, owner} = create_organization_with_owner!()
      new_user = create_user!()

      assert {:ok, membership} =
               OrgMembership
               |> Ash.Changeset.for_create(:create, %{role: :member}, actor: owner)
               |> Ash.Changeset.manage_relationship(:organization, org, type: :append)
               |> Ash.Changeset.manage_relationship(:user, new_user, type: :append)
               |> Ash.create()

      assert membership.role == :member
    end

    test "admin can add members to their organization" do
      {org, _owner} = create_organization_with_owner!()
      admin = create_user!()
      create_org_membership!(organization: org, user: admin, role: :admin)
      new_user = create_user!()

      assert {:ok, membership} =
               OrgMembership
               |> Ash.Changeset.for_create(:create, %{role: :member}, actor: admin)
               |> Ash.Changeset.manage_relationship(:organization, org, type: :append)
               |> Ash.Changeset.manage_relationship(:user, new_user, type: :append)
               |> Ash.create()

      assert membership.role == :member
    end

    test "admin cannot add owners" do
      {org, _owner} = create_organization_with_owner!()
      admin = create_user!()
      create_org_membership!(organization: org, user: admin, role: :admin)
      new_user = create_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               OrgMembership
               |> Ash.Changeset.for_create(:create, %{role: :owner}, actor: admin)
               |> Ash.Changeset.manage_relationship(:organization, org, type: :append)
               |> Ash.Changeset.manage_relationship(:user, new_user, type: :append)
               |> Ash.create()
    end

    test "regular member cannot add members" do
      {org, _owner} = create_organization_with_owner!()
      member = create_user!()
      create_org_membership!(organization: org, user: member, role: :member)
      new_user = create_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               OrgMembership
               |> Ash.Changeset.for_create(:create, %{role: :member}, actor: member)
               |> Ash.Changeset.manage_relationship(:organization, org, type: :append)
               |> Ash.Changeset.manage_relationship(:user, new_user, type: :append)
               |> Ash.create()
    end

    test "non-member cannot add members" do
      {org, _owner} = create_organization_with_owner!()
      outsider = create_user!()
      new_user = create_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               OrgMembership
               |> Ash.Changeset.for_create(:create, %{role: :member}, actor: outsider)
               |> Ash.Changeset.manage_relationship(:organization, org, type: :append)
               |> Ash.Changeset.manage_relationship(:user, new_user, type: :append)
               |> Ash.create()
    end
  end

  describe "read policies" do
    test "owner can read all memberships in their organization" do
      {org, owner} = create_organization_with_owner!()
      member = create_user!()
      create_org_membership!(organization: org, user: member, role: :member)

      assert {:ok, memberships} =
               OrgMembership
               |> Ash.Query.filter(organization_id == ^org.id)
               |> Ash.read(actor: owner)

      assert length(memberships) == 2
    end

    test "admin can read all memberships in their organization" do
      {org, _owner} = create_organization_with_owner!()
      admin = create_user!()
      create_org_membership!(organization: org, user: admin, role: :admin)

      assert {:ok, memberships} =
               OrgMembership
               |> Ash.Query.filter(organization_id == ^org.id)
               |> Ash.read(actor: admin)

      assert length(memberships) == 2
    end

    test "member can read only their own membership" do
      {org, _owner} = create_organization_with_owner!()
      member = create_user!()
      membership = create_org_membership!(organization: org, user: member, role: :member)

      assert {:ok, memberships} =
               OrgMembership
               |> Ash.Query.filter(organization_id == ^org.id)
               |> Ash.read(actor: member)

      # Member can only see their own membership
      assert length(memberships) == 1
      assert hd(memberships).id == membership.id
    end

    test "non-member cannot read any memberships" do
      {org, _owner} = create_organization_with_owner!()
      outsider = create_user!()

      assert {:ok, []} =
               OrgMembership
               |> Ash.Query.filter(organization_id == ^org.id)
               |> Ash.read(actor: outsider)
    end
  end

  describe "destroy policies" do
    test "owner can remove members" do
      {org, owner} = create_organization_with_owner!()
      member = create_user!()
      membership = create_org_membership!(organization: org, user: member, role: :member)

      assert :ok =
               membership
               |> Ash.Changeset.for_destroy(:destroy, %{}, actor: owner)
               |> Ash.destroy()
    end

    test "admin can remove regular members" do
      {org, _owner} = create_organization_with_owner!()
      admin = create_user!()
      create_org_membership!(organization: org, user: admin, role: :admin)
      member = create_user!()
      membership = create_org_membership!(organization: org, user: member, role: :member)

      assert :ok =
               membership
               |> Ash.Changeset.for_destroy(:destroy, %{}, actor: admin)
               |> Ash.destroy()
    end

    test "admin cannot remove owner" do
      {org, owner} = create_organization_with_owner!()
      admin = create_user!()
      create_org_membership!(organization: org, user: admin, role: :admin)

      # Get owner's membership
      {:ok, [owner_membership]} =
        OrgMembership
        |> Ash.Query.filter(organization_id == ^org.id and user_id == ^owner.id)
        |> Ash.read(authorize?: false)

      assert {:error, %Ash.Error.Forbidden{}} =
               owner_membership
               |> Ash.Changeset.for_destroy(:destroy, %{}, actor: admin)
               |> Ash.destroy()
    end
  end
end
