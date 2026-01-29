defmodule Dash.Accounts.UserTest do
  use Dash.DataCase, async: true

  alias Dash.Accounts.User

  describe "register_with_password/1" do
    test "creates a user with valid attributes" do
      attrs = user_attrs()

      assert {:ok, user} =
               User
               |> Ash.Changeset.for_create(:register_with_password, attrs)
               |> Ash.create(authorize?: false)

      assert to_string(user.email) == String.downcase(attrs.email)
      assert user.hashed_password != nil
      assert user.hashed_password != attrs.password
    end

    test "requires email" do
      attrs = %{password: "password123", password_confirmation: "password123"}

      assert {:error, changeset} =
               User
               |> Ash.Changeset.for_create(:register_with_password, attrs)
               |> Ash.create(authorize?: false)

      assert %{email: [error]} = ash_errors_on(changeset)
      assert error =~ "required"
    end

    test "requires password" do
      attrs = %{email: unique_email()}

      assert {:error, changeset} =
               User
               |> Ash.Changeset.for_create(:register_with_password, attrs)
               |> Ash.create(authorize?: false)

      assert %{password: [_]} = ash_errors_on(changeset)
    end

    test "requires password confirmation to match" do
      attrs = %{
        email: unique_email(),
        password: "password123",
        password_confirmation: "different123"
      }

      assert {:error, changeset} =
               User
               |> Ash.Changeset.for_create(:register_with_password, attrs)
               |> Ash.create(authorize?: false)

      assert %{password_confirmation: [error]} = ash_errors_on(changeset)
      assert error =~ "does not match"
    end

    test "requires password to be at least 8 characters" do
      attrs = %{
        email: unique_email(),
        password: "short",
        password_confirmation: "short"
      }

      assert {:error, changeset} =
               User
               |> Ash.Changeset.for_create(:register_with_password, attrs)
               |> Ash.create(authorize?: false)

      assert %{password: [error]} = ash_errors_on(changeset)
      assert error =~ "length"
    end

    test "enforces unique email" do
      user = create_user!()

      attrs = %{
        email: user.email,
        password: "password123",
        password_confirmation: "password123"
      }

      assert {:error, _changeset} =
               User
               |> Ash.Changeset.for_create(:register_with_password, attrs)
               |> Ash.create(authorize?: false)
    end

    test "email is case insensitive" do
      _user = create_user!(email: "test@example.com")

      attrs = %{
        email: "TEST@EXAMPLE.COM",
        password: "password123",
        password_confirmation: "password123"
      }

      assert {:error, _changeset} =
               User
               |> Ash.Changeset.for_create(:register_with_password, attrs)
               |> Ash.create(authorize?: false)
    end
  end

  describe "sign_in_with_password/1" do
    test "returns user with valid credentials" do
      password = "password123"
      user = create_user!(password: password)

      assert {:ok, signed_in_user} =
               User
               |> Ash.Query.for_read(:sign_in_with_password, %{
                 email: user.email,
                 password: password
               })
               |> Ash.read_one(authorize?: false)

      assert signed_in_user.id == user.id
    end

    test "returns error with invalid password" do
      user = create_user!(password: "password123")

      assert {:error, _} =
               User
               |> Ash.Query.for_read(:sign_in_with_password, %{
                 email: user.email,
                 password: "wrongpassword"
               })
               |> Ash.read_one(authorize?: false)
    end

    test "returns error with non-existent email" do
      assert {:error, _} =
               User
               |> Ash.Query.for_read(:sign_in_with_password, %{
                 email: "nonexistent@example.com",
                 password: "password123"
               })
               |> Ash.read_one(authorize?: false)
    end
  end

  describe "get_by_email/1" do
    test "returns user when email exists" do
      user = create_user!()

      assert {:ok, found_user} =
               User
               |> Ash.Query.for_read(:get_by_email, %{email: user.email})
               |> Ash.read_one(authorize?: false)

      assert found_user.id == user.id
    end

    test "returns nil when email doesn't exist" do
      assert {:ok, nil} =
               User
               |> Ash.Query.for_read(:get_by_email, %{email: "nonexistent@example.com"})
               |> Ash.read_one(authorize?: false)
    end
  end

  # Helper function for unique emails in this test file
  defp unique_email do
    "user_#{System.unique_integer([:positive])}@example.com"
  end

  # Helper to extract errors from Ash changeset/error
  # Named ash_errors_on to avoid conflict with Ecto-based errors_on in DataCase
  defp ash_errors_on(%Ash.Error.Invalid{} = error) do
    error.errors
    |> Enum.reduce(%{}, fn err, acc ->
      field = Map.get(err, :field) || :base
      message = extract_error_message(err)
      Map.update(acc, field, [message], &[message | &1])
    end)
  end

  # Handle Required errors - they don't have a message field, create one
  defp extract_error_message(%Ash.Error.Changes.Required{field: field}) do
    "#{field} is required"
  end

  # Handle InvalidArgument errors - interpolate vars into message
  defp extract_error_message(%Ash.Error.Changes.InvalidArgument{message: message, vars: vars}) do
    Enum.reduce(vars, message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  # Fallback for other error types with a message field
  defp extract_error_message(%{message: message}) when is_binary(message), do: message
  defp extract_error_message(error), do: inspect(error)
end
