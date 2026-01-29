defmodule Dash.Repo.Migrations.AddUserRole do
  @moduledoc """
  Adds role field to users table for system-level access control.
  """

  use Ecto.Migration

  def up do
    alter table(:users) do
      add :role, :text, null: false, default: "user"
    end
  end

  def down do
    alter table(:users) do
      remove :role
    end
  end
end
