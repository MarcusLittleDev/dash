defmodule Dash.Repo.Migrations.CreateUsersAndTokens do
  use Ecto.Migration

  def up do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :email, :citext, null: false
      add :hashed_password, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])

    create table(:user_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :subject, :text, null: false
      add :jti, :text, null: false
      add :token, :text, null: false
      add :purpose, :text, null: false
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:user_tokens, [:jti])
    create index(:user_tokens, [:token])
    create index(:user_tokens, [:purpose])
    create index(:user_tokens, [:expires_at])
  end

  def down do
    drop table(:user_tokens)
    drop table(:users)
  end
end
