defmodule DashWeb.DashboardLive.Form do
  use DashWeb, :live_view

  require Ash.Query
  alias Dash.Dashboards.Dashboard

  @impl true
  def mount(params, _session, socket) do
    {dashboard, action} =
      case params do
        %{"id" => id} ->
          {load_dashboard(id, socket.assigns.current_user), :edit}

        _ ->
          {%Dashboard{}, :new}
      end

    socket =
      socket
      |> assign(:dashboard, dashboard)
      |> assign(:action, action)
      |> assign(:page_title, if(action == :new, do: "New Dashboard", else: "Edit Dashboard"))
      |> assign(:form, to_form(%{"name" => dashboard.name, "description" => dashboard.description, "is_default" => dashboard.is_default || false}))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"dashboard" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params))}
  end

  @impl true
  def handle_event("save", %{"dashboard" => params}, socket) do
    case socket.assigns.action do
      :new -> create_dashboard(socket, params)
      :edit -> update_dashboard(socket, params)
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case Ash.destroy(socket.assigns.dashboard, actor: socket.assigns.current_user) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Dashboard deleted successfully")
         |> push_navigate(to: ~p"/dashboards")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete dashboard")}
    end
  end

  defp create_dashboard(socket, params) do
    org = socket.assigns.current_org

    case Dashboard
         |> Ash.Changeset.for_create(:create, %{
           name: params["name"],
           description: params["description"],
           is_default: params["is_default"] == "true",
           organization_id: org.id,
           created_by_id: socket.assigns.current_user.id
         })
         |> Ash.create(actor: socket.assigns.current_user) do
      {:ok, dashboard} ->
        {:noreply,
         socket
         |> put_flash(:info, "Dashboard created successfully")
         |> push_navigate(to: ~p"/dashboards/#{dashboard.id}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, format_errors(changeset))
         |> assign(:form, to_form(params))}
    end
  end

  defp update_dashboard(socket, params) do
    case socket.assigns.dashboard
         |> Ash.Changeset.for_update(:update, %{
           name: params["name"],
           description: params["description"],
           is_default: params["is_default"] == "true"
         })
         |> Ash.update(actor: socket.assigns.current_user) do
      {:ok, dashboard} ->
        {:noreply,
         socket
         |> put_flash(:info, "Dashboard updated successfully")
         |> push_navigate(to: ~p"/dashboards/#{dashboard.id}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, format_errors(changeset))
         |> assign(:form, to_form(params))}
    end
  end

  defp format_errors(error) do
    case error do
      %Ash.Changeset{errors: errors} ->
        errors
        |> Enum.map(&Exception.message/1)
        |> Enum.join(", ")

      %Ash.Error.Invalid{} = err ->
        Exception.message(err)

      other ->
        inspect(other)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto">
      <div class="flex items-center space-x-3 mb-6">
        <.link navigate={return_path(@action, @dashboard)} class="text-gray-400 hover:text-gray-600">
          <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
        </.link>
        <h1 class="text-2xl font-semibold text-gray-900"><%= @page_title %></h1>
      </div>

      <div class="bg-white shadow rounded-lg">
        <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-6 p-6">
          <div>
            <label for="name" class="block text-sm font-medium text-gray-700">
              Dashboard Name
            </label>
            <input
              type="text"
              name="dashboard[name]"
              id="name"
              value={@form[:name].value}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              placeholder="My Dashboard"
            />
          </div>

          <div>
            <label for="description" class="block text-sm font-medium text-gray-700">
              Description
            </label>
            <textarea
              name="dashboard[description]"
              id="description"
              rows="3"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              placeholder="Optional description for this dashboard"
            ><%= @form[:description].value %></textarea>
          </div>

          <div class="flex items-center">
            <input
              type="checkbox"
              name="dashboard[is_default]"
              id="is_default"
              value="true"
              checked={@form[:is_default].value == true || @form[:is_default].value == "true"}
              class="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
            />
            <label for="is_default" class="ml-2 block text-sm text-gray-700">
              Set as default dashboard for this organization
            </label>
          </div>

          <div class="flex justify-between pt-4 border-t">
            <div>
              <%= if @action == :edit do %>
                <button
                  type="button"
                  phx-click="delete"
                  data-confirm="Are you sure you want to delete this dashboard? This will also delete all widgets."
                  class="inline-flex items-center px-4 py-2 border border-red-300 text-sm font-medium rounded-md text-red-700 bg-white hover:bg-red-50"
                >
                  Delete Dashboard
                </button>
              <% end %>
            </div>
            <div class="flex space-x-3">
              <.link
                navigate={return_path(@action, @dashboard)}
                class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
              >
                Cancel
              </.link>
              <button
                type="submit"
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700"
              >
                <%= if @action == :new, do: "Create Dashboard", else: "Save Changes" %>
              </button>
            </div>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  defp load_dashboard(id, actor) do
    Dashboard
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!(actor: actor)
  end

  defp return_path(:new, _dashboard), do: ~p"/dashboards"
  defp return_path(:edit, dashboard), do: ~p"/dashboards/#{dashboard.id}"
end
