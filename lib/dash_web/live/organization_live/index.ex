defmodule DashWeb.OrganizationLive.Index do
  use DashWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Listing Organizations
        <:actions>
          <.button variant="primary" navigate={~p"/organizations/new"}>
            <.icon name="hero-plus" /> New Organization
          </.button>
        </:actions>
      </.header>

      <.table
        id="organizations"
        rows={@streams.organizations}
        row_click={fn {_id, organization} -> JS.navigate(~p"/organizations/#{organization}") end}
      >
        <:col :let={{_id, organization}} label="Id">{organization.id}</:col>

        <:col :let={{_id, organization}} label="Name">{organization.name}</:col>

        <:col :let={{_id, organization}} label="Slug">{organization.slug}</:col>

        <:action :let={{_id, organization}}>
          <div class="sr-only">
            <.link navigate={~p"/organizations/#{organization}"}>Show</.link>
          </div>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Organizations")
     |> stream(:organizations, Ash.read!(Dash.Accounts.Organization))}
  end
end
