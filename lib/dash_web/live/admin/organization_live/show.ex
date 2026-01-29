defmodule DashWeb.Admin.OrganizationLive.Show do
  use DashWeb, :live_view

  alias Dash.Accounts.{Organization, OrgMembership}

  require Ash.Query

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    actor = socket.assigns.current_user

    organization =
      Ash.get!(Organization, id,
        actor: actor,
        load: [:org_memberships]
      )

    # Load memberships with user info
    # Note: OrgMembership policies may need updating for employee access
    memberships =
      OrgMembership
      |> Ash.Query.filter(organization_id == ^id)
      |> Ash.Query.load(:user)
      |> Ash.read!(authorize?: false)

    {:ok,
     socket
     |> assign(:page_title, organization.name)
     |> assign(:organization, organization)
     |> stream(:memberships, memberships)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.header>
        {@organization.name}
        <:subtitle>
          <span class={[
            "badge",
            @organization.active && "badge-success",
            !@organization.active && "badge-error"
          ]}>
            {if @organization.active, do: "Active", else: "Inactive"}
          </span>
          <span class="ml-2 text-base-content/60">/{@organization.slug}</span>
        </:subtitle>
        <:actions>
          <.link navigate={~p"/admin/organizations/#{@organization}/edit"}>
            <.button variant="primary">
              <.icon name="hero-pencil" class="w-4 h-4 mr-1" /> Edit
            </.button>
          </.link>
        </:actions>
      </.header>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title text-lg">Details</h3>
            <dl class="space-y-2">
              <div>
                <dt class="text-sm text-base-content/60">Created</dt>
                <dd>{Calendar.strftime(@organization.inserted_at, "%Y-%m-%d %H:%M")}</dd>
              </div>
              <div>
                <dt class="text-sm text-base-content/60">Last Updated</dt>
                <dd>{Calendar.strftime(@organization.updated_at, "%Y-%m-%d %H:%M")}</dd>
              </div>
              <div :if={@organization.deactivated_at}>
                <dt class="text-sm text-base-content/60">Deactivated</dt>
                <dd>{Calendar.strftime(@organization.deactivated_at, "%Y-%m-%d %H:%M")}</dd>
              </div>
            </dl>
          </div>
        </div>

        <div class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title text-lg">Members</h3>
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Email</th>
                    <th>Role</th>
                  </tr>
                </thead>
                <tbody id="memberships" phx-update="stream">
                  <tr :for={{dom_id, membership} <- @streams.memberships} id={dom_id}>
                    <td>{to_string(membership.user.email)}</td>
                    <td>
                      <span class={[
                        "badge badge-sm",
                        membership.role == :owner && "badge-primary",
                        membership.role == :admin && "badge-secondary",
                        membership.role == :member && "badge-ghost"
                      ]}>
                        {membership.role}
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <.link navigate={~p"/admin/organizations"} class="btn btn-ghost">
        <.icon name="hero-arrow-left" class="w-4 h-4 mr-1" /> Back to Organizations
      </.link>
    </div>
    """
  end
end
