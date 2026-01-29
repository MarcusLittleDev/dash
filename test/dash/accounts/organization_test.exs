defmodule Dash.Accounts.OrganizationTest do
  use Dash.DataCase, async: true

  alias Dash.Accounts.Organization

  require Ash.Query

  describe "create/1" do
    test "creates an organization with valid name (bypassing authorization)" do
      assert {:ok, org} =
               Organization
               |> Ash.Changeset.for_create(:create, %{name: "Test Organization"})
               |> Ash.create(authorize?: false)

      assert org.name == "Test Organization"
      assert org.slug == "test-organization"
      assert org.active == true
      assert org.deactivated_at == nil
    end

    test "auto-generates slug from name" do
      assert {:ok, org} =
               Organization
               |> Ash.Changeset.for_create(:create, %{name: "My Amazing Company"})
               |> Ash.create(authorize?: false)

      assert org.slug == "my-amazing-company"
    end

    test "requires name" do
      assert {:error, changeset} =
               Organization
               |> Ash.Changeset.for_create(:create, %{})
               |> Ash.create(authorize?: false)

      assert has_error?(changeset, :name)
    end

    test "enforces unique name" do
      create_organization!(name: "Unique Org")

      assert {:error, _changeset} =
               Organization
               |> Ash.Changeset.for_create(:create, %{name: "Unique Org"})
               |> Ash.create(authorize?: false)
    end

    test "creation is forbidden for regular users (policy)" do
      user = create_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               Organization
               |> Ash.Changeset.for_create(:create, %{name: "Test Org"}, actor: user)
               |> Ash.create()
    end
  end

  describe "read policies" do
    test "user can read organizations they are a member of" do
      {org, owner} = create_organization_with_owner!()

      assert {:ok, [found_org]} =
               Organization
               |> Ash.Query.filter(id == ^org.id)
               |> Ash.read(actor: owner)

      assert found_org.id == org.id
    end

    test "user cannot read organizations they are not a member of" do
      {org, _owner} = create_organization_with_owner!()
      other_user = create_user!()

      assert {:ok, []} =
               Organization
               |> Ash.Query.filter(id == ^org.id)
               |> Ash.read(actor: other_user)
    end
  end

  describe "update/1" do
    test "owner can update organization name" do
      {org, owner} = create_organization_with_owner!()

      assert {:ok, updated_org} =
               org
               |> Ash.Changeset.for_update(:update, %{name: "New Name"}, actor: owner)
               |> Ash.update(atomic_upgrade?: false)

      assert updated_org.name == "New Name"
      assert updated_org.slug == "new-name"
    end

    test "non-owner member cannot update organization" do
      {org, _owner} = create_organization_with_owner!()
      member = create_user!()
      create_org_membership!(organization: org, user: member, role: :member)

      assert {:error, %Ash.Error.Forbidden{}} =
               org
               |> Ash.Changeset.for_update(:update, %{name: "New Name"}, actor: member)
               |> Ash.update(atomic_upgrade?: false)
    end

    test "admin cannot update organization" do
      {org, _owner} = create_organization_with_owner!()
      admin = create_user!()
      create_org_membership!(organization: org, user: admin, role: :admin)

      assert {:error, %Ash.Error.Forbidden{}} =
               org
               |> Ash.Changeset.for_update(:update, %{name: "New Name"}, actor: admin)
               |> Ash.update(atomic_upgrade?: false)
    end

    test "non-member cannot update organization" do
      {org, _owner} = create_organization_with_owner!()
      other_user = create_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               org
               |> Ash.Changeset.for_update(:update, %{name: "New Name"}, actor: other_user)
               |> Ash.update(atomic_upgrade?: false)
    end
  end

  describe "deactivate/1" do
    test "deactivation is forbidden (admin-only)" do
      {org, owner} = create_organization_with_owner!()

      assert {:error, %Ash.Error.Forbidden{}} =
               org
               |> Ash.Changeset.for_update(:deactivate, %{}, actor: owner)
               |> Ash.update(atomic_upgrade?: false)
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
