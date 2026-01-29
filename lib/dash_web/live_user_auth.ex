defmodule DashWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component
  use DashWeb, :verified_routes

  @doc """
  LiveView on_mount callbacks for authentication and authorization.

  ## Clauses

  - `:current_user` - Fetches the current user from session (for nested LiveViews)
  - `:live_user_optional` - Allows guests, assigns nil if no user
  - `:live_user_required` - Redirects to sign-in if not authenticated
  - `:live_no_user` - Redirects to home if already authenticated
  - `:live_employee_required` - Requires employee or superadmin role
  - `:live_superadmin_required` - Requires superadmin role
  """
  def on_mount(clause, params, session, socket)

  def on_mount(:current_user, _params, session, socket) do
    {:cont, AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)}
  end

  def on_mount(:live_user_optional, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:live_employee_required, _params, _session, socket) do
    user = socket.assigns[:current_user]

    if user && user.role in [:employee, :superadmin] do
      {:cont, socket}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "You don't have access to this area")
       |> Phoenix.LiveView.redirect(to: ~p"/")}
    end
  end

  def on_mount(:live_superadmin_required, _params, _session, socket) do
    user = socket.assigns[:current_user]

    if user && user.role == :superadmin do
      {:cont, socket}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "You don't have access to this area")
       |> Phoenix.LiveView.redirect(to: ~p"/")}
    end
  end
end
