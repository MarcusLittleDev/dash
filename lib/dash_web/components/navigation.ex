defmodule DashWeb.Navigation do
  @moduledoc "Navigation components for the app shell"
  use Phoenix.Component
  import DashWeb.CoreComponents
  use DashWeb, :verified_routes

  attr :current_user, :map, required: true
  attr :current_org, :map, default: nil
  attr :organizations, :list, default: []
  attr :teams, :list, default: []

  def sidebar(assigns) do
    ~H"""
    <aside class="drawer-side">
      <label for="main-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
      <div class="menu bg-base-200 text-base-content min-h-full w-64 p-4 flex flex-col">
        <!-- Logo -->
        <div class="flex items-center gap-2 px-2 mb-4">
          <img src={~p"/images/logo.svg"} class="h-8 w-8" alt="Dash" />
          <span class="text-xl font-bold">Dash</span>
        </div>

        <.org_switcher organizations={@organizations} current_org={@current_org} />
        <.team_list teams={@teams} current_org={@current_org} />
        <.nav_menu />

        <div class="flex-1"></div>

        <.user_menu current_user={@current_user} />
      </div>
    </aside>
    """
  end

  attr :organizations, :list, default: []
  attr :current_org, :map, default: nil

  def org_switcher(assigns) do
    ~H"""
    <div class="dropdown dropdown-bottom w-full mb-4">
      <div tabindex="0" role="button" class="btn btn-ghost justify-between w-full">
        <span class="truncate">
          <%= if @current_org, do: @current_org.name, else: "Select Organization" %>
        </span>
        <.icon name="hero-chevron-down" class="h-4 w-4" />
      </div>
      <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-full">
        <%= for org <- @organizations do %>
          <li>
            <button
              phx-click="switch_org"
              phx-value-org_id={org.id}
              class={if @current_org && @current_org.id == org.id, do: "active", else: ""}
            >
              <span class="truncate"><%= org.name %></span>
              <span class="badge badge-sm badge-ghost"><%= org.user_role %></span>
            </button>
          </li>
        <% end %>
        <%= if @organizations == [] do %>
          <li class="disabled"><span class="text-base-content/50">No organizations</span></li>
        <% end %>
      </ul>
    </div>
    """
  end

  attr :teams, :list, default: []
  attr :current_org, :map, default: nil

  def team_list(assigns) do
    ~H"""
    <div class="mb-4">
      <div class="px-2 py-1 text-xs font-semibold text-base-content/60 uppercase tracking-wider">
        Teams
      </div>
      <ul class="menu menu-sm">
        <%= for team <- @teams do %>
          <li>
            <.link navigate={~p"/teams/#{team.id}"} class="flex justify-between">
              <span class="truncate"><%= team.name %></span>
              <%= if team.user_role do %>
                <span class="badge badge-xs badge-ghost"><%= team.user_role %></span>
              <% end %>
            </.link>
          </li>
        <% end %>
        <%= if @teams == [] && @current_org do %>
          <li class="disabled"><span class="text-base-content/50 text-sm px-2">No teams yet</span></li>
        <% end %>
      </ul>
    </div>
    """
  end

  def nav_menu(assigns) do
    ~H"""
    <div class="mb-4">
      <div class="px-2 py-1 text-xs font-semibold text-base-content/60 uppercase tracking-wider">
        Navigation
      </div>
      <ul class="menu menu-sm">
        <li>
          <.link navigate={~p"/organizations"}>
            <.icon name="hero-building-office-2" class="h-4 w-4" />
            Organizations
          </.link>
        </li>
        <li>
          <.link navigate={~p"/teams"}>
            <.icon name="hero-user-group" class="h-4 w-4" />
            Teams
          </.link>
        </li>
      </ul>
    </div>
    """
  end

  attr :current_user, :map, required: true

  def user_menu(assigns) do
    ~H"""
    <div class="border-t border-base-300 pt-4">
      <div class="dropdown dropdown-top w-full">
        <div tabindex="0" role="button" class="btn btn-ghost justify-start w-full">
          <div class="avatar placeholder">
            <div class="bg-neutral text-neutral-content rounded-full w-8">
              <span class="text-xs"><%= String.first(@current_user.email) |> String.upcase() %></span>
            </div>
          </div>
          <span class="truncate flex-1 text-left"><%= @current_user.email %></span>
          <.icon name="hero-chevron-up" class="h-4 w-4" />
        </div>
        <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-full mb-2">
          <li>
            <.link navigate={~p"/org_memberships"}>
              <.icon name="hero-identification" class="h-4 w-4" />
              My Memberships
            </.link>
          </li>
          <li class="border-t border-base-200 mt-1 pt-1">
            <.link href={~p"/sign-out"} method="delete" class="text-error">
              <.icon name="hero-arrow-right-on-rectangle" class="h-4 w-4" />
              Sign Out
            </.link>
          </li>
        </ul>
      </div>
    </div>
    """
  end
end
