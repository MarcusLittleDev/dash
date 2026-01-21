defmodule DashWeb.OrgMembershipLive.Form do
  use DashWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage org_membership records in your database.</:subtitle>
      </.header>

      <.form
        for={@form}
        id="org_membership-form"
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:role]}
          type="select"
          label="Role"
          options={
            Ash.Resource.Info.attribute(Dash.Accounts.OrgMembership, :role).constraints[:one_of]
          }
        />

        <.button phx-disable-with="Saving..." variant="primary">Save Org membership</.button>
        <.button navigate={return_path(@return_to, @org_membership)}>Cancel</.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    org_membership =
      case params["id"] do
        nil -> nil
        id -> Ash.get!(Dash.Accounts.OrgMembership, id)
      end

    action = if is_nil(org_membership), do: "New", else: "Edit"
    page_title = action <> " " <> "Org membership"

    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> assign(org_membership: org_membership)
     |> assign(:page_title, page_title)
     |> assign_form()}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  @impl true
  def handle_event("validate", %{"org_membership" => org_membership_params}, socket) do
    {:noreply,
     assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, org_membership_params))}
  end

  def handle_event("save", %{"org_membership" => org_membership_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: org_membership_params) do
      {:ok, org_membership} ->
        notify_parent({:saved, org_membership})

        socket =
          socket
          |> put_flash(:info, "Org membership #{socket.assigns.form.source.type}d successfully")
          |> push_navigate(to: return_path(socket.assigns.return_to, org_membership))

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{org_membership: org_membership}} = socket) do
    form =
      if org_membership do
        AshPhoenix.Form.for_update(org_membership, :update, as: "org_membership")
      else
        AshPhoenix.Form.for_create(Dash.Accounts.OrgMembership, :create, as: "org_membership")
      end

    assign(socket, form: to_form(form))
  end

  defp return_path("index", _org_membership), do: ~p"/org_memberships"
  defp return_path("show", org_membership), do: ~p"/org_memberships/#{org_membership.id}"
end
