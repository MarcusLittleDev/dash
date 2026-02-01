defmodule DashWeb.Admin.OrganizationLive.Form do
  use DashWeb, :live_view
  use DashWeb.OrgContextLive

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      {@page_title}
      <:subtitle>Use this form to manage organization records in your database.</:subtitle>
    </.header>

    <.form
      for={@form}
      id="organization-form"
      phx-change="validate"
      phx-submit="save"
    >
      <.input
        field={@form[:name]}
        type="text"
        label="Name"
      />

      <.button phx-disable-with="Saving..." variant="primary">Save Organization</.button>
      <.button navigate={return_path(@return_to, @organization)}>Cancel</.button>
    </.form>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    organization =
      case params["id"] do
        nil -> nil
        id -> Ash.get!(Dash.Accounts.Organization, id)
      end

    action = if is_nil(organization), do: "New", else: "Edit"
    page_title = action <> " " <> "Organization"

    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> assign(organization: organization)
     |> assign(:page_title, page_title)
     |> assign_form()}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  @impl true
  def handle_event("validate", %{"organization" => organization_params}, socket) do
    {:noreply,
     assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, organization_params))}
  end

  def handle_event("save", %{"organization" => organization_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form,
           params: organization_params,
           actor: socket.assigns.current_user
         ) do
      {:ok, organization} ->
        notify_parent({:saved, organization})

        socket =
          socket
          |> put_flash(:info, "Organization #{socket.assigns.form.source.type}d successfully")
          |> push_navigate(to: return_path(socket.assigns.return_to, organization))

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{organization: organization, current_user: current_user}} = socket) do
    form =
      if organization do
        AshPhoenix.Form.for_update(organization, :update, as: "organization", actor: current_user)
      else
        AshPhoenix.Form.for_create(Dash.Accounts.Organization, :create,
          as: "organization",
          actor: current_user
        )
      end

    assign(socket, form: to_form(form))
  end

  defp return_path("index", _organization), do: ~p"/admin/organizations"
  defp return_path("show", organization), do: ~p"/admin/organizations/#{organization.id}"
end
