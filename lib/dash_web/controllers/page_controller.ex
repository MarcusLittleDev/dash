defmodule DashWeb.PageController do
  use DashWeb, :controller

  def home(conn, _params) do
    # If user is authenticated, redirect based on role
    case conn.assigns[:current_user] do
      %{role: role} when role in [:employee, :superadmin] ->
        redirect(conn, to: ~p"/admin")

      %{} ->
        redirect(conn, to: ~p"/home")

      nil ->
        render(conn, :home)
    end
  end
end
