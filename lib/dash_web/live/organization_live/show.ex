defmodule DashWeb.OrganizationLive.Show do
  use DashWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Organization {@organization.id}
        <:subtitle>This is a organization record from your database.</:subtitle>
      </.header>

      <.list>
        <:item title="Id">{@organization.id}</:item>

        <:item title="Name">{@organization.name}</:item>

        <:item title="Slug">{@organization.slug}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Organization")
     |> assign(:organization, Ash.get!(Dash.Accounts.Organization, id))}
  end
end
