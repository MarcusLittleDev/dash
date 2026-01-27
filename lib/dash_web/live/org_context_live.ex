defmodule DashWeb.OrgContextLive do
  @moduledoc "Shared event handlers for org/team context switching"

  defmacro __using__(_opts) do
    quote do
      def handle_event("switch_org", %{"org_id" => org_id}, socket) do
        organizations = socket.assigns.organizations
        current_org = Enum.find(organizations, &(&1.id == org_id))

        socket =
          socket
          |> assign(:current_org, current_org)
          |> DashWeb.Hooks.LiveOrgContext.reload_teams()

        {:noreply, socket}
      end
    end
  end
end
