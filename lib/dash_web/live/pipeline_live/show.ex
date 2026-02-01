defmodule DashWeb.PipelineLive.Show do
  use DashWeb, :live_view

  require Ash.Query
  alias Dash.Pipelines.Pipeline
  alias Dash.Pipelines.DataMapping
  alias Dash.Pipelines.Executor
  alias Dash.Pipelines.Workers.PollingWorker

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:show_mapping_modal, false)
      |> assign(:mappings, [])
      |> assign(:editing_mappings, [])
      |> assign(:mapping_errors, [])
      |> assign(:running, false)
      |> assign(:last_execution, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case load_pipeline(id, socket.assigns.current_user) do
      {:ok, pipeline} ->
        mappings = load_mappings(pipeline.id, socket.assigns.current_user)

        socket =
          socket
          |> assign(:page_title, pipeline.name)
          |> assign(:pipeline, pipeline)
          |> assign(:mappings, mappings)

        {:noreply, socket}

      {:error, _} ->
        socket =
          socket
          |> put_flash(:error, "Pipeline not found")
          |> push_navigate(to: ~p"/pipelines")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("activate", _params, socket) do
    case update_status(socket.assigns.pipeline, :active, socket.assigns.current_user) do
      {:ok, pipeline} ->
        # Schedule the first job if this is a polling pipeline
        if pipeline.type == :polling do
          # Schedule immediately (schedule_in: 0 means run now)
          PollingWorker.schedule(pipeline, schedule_in: 0)
        end

        socket =
          socket
          |> put_flash(:info, "Pipeline activated and scheduled")
          |> assign(:pipeline, pipeline)

        {:noreply, socket}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to activate: #{inspect(error)}")}
    end
  end

  @impl true
  def handle_event("deactivate", _params, socket) do
    pipeline = socket.assigns.pipeline

    # Cancel any scheduled jobs first
    if pipeline.type == :polling do
      PollingWorker.cancel_all(pipeline.id)
    end

    case update_status(pipeline, :inactive, socket.assigns.current_user) do
      {:ok, updated_pipeline} ->
        socket =
          socket
          |> put_flash(:info, "Pipeline deactivated and scheduled jobs cancelled")
          |> assign(:pipeline, updated_pipeline)

        {:noreply, socket}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to deactivate: #{inspect(error)}")}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    if socket.assigns.pipeline.status == :inactive do
      case Ash.destroy(socket.assigns.pipeline, actor: socket.assigns.current_user) do
        :ok ->
          socket =
            socket
            |> put_flash(:info, "Pipeline deleted")
            |> push_navigate(to: ~p"/pipelines")

          {:noreply, socket}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, "Failed to delete: #{inspect(error)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Cannot delete an active pipeline. Deactivate it first.")}
    end
  end

  @impl true
  def handle_event("run_now", _params, socket) do
    socket = assign(socket, :running, true)

    # Run the pipeline
    case Executor.execute(socket.assigns.pipeline) do
      {:ok, execution_log} ->
        socket =
          socket
          |> assign(:running, false)
          |> assign(:last_execution, execution_log)
          |> put_flash(:info, format_execution_result(execution_log))

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:running, false)
          |> put_flash(:error, "Pipeline execution failed: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  defp format_execution_result(log) do
    case log.status do
      :success ->
        "Pipeline executed successfully! Fetched #{log.records_fetched} record(s), stored #{log.records_stored} record(s) in #{log.duration_ms}ms"

      :no_data ->
        "Pipeline executed successfully but no data was returned from source (#{log.duration_ms}ms)"

      :error ->
        "Pipeline execution failed: #{log.error_message}"
    end
  end

  @impl true
  def handle_event("open_mapping_modal", _params, socket) do
    # Convert existing mappings to editing format
    editing_mappings =
      socket.assigns.mappings
      |> Enum.map(fn m ->
        %{
          "id" => m.id,
          "source_field" => m.source_field,
          "target_field" => m.target_field,
          "temp_id" => nil
        }
      end)

    # Add empty row if no mappings exist
    editing_mappings =
      if editing_mappings == [] do
        [%{"id" => nil, "source_field" => "", "target_field" => "", "temp_id" => generate_temp_id()}]
      else
        editing_mappings
      end

    socket =
      socket
      |> assign(:show_mapping_modal, true)
      |> assign(:editing_mappings, editing_mappings)
      |> assign(:mapping_errors, [])

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_mapping_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_mapping_modal, false)
      |> assign(:editing_mappings, [])
      |> assign(:mapping_errors, [])

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_mapping_row", _params, socket) do
    new_row = %{"id" => nil, "source_field" => "", "target_field" => "", "temp_id" => generate_temp_id()}
    editing_mappings = socket.assigns.editing_mappings ++ [new_row]
    {:noreply, assign(socket, :editing_mappings, editing_mappings)}
  end

  @impl true
  def handle_event("remove_mapping_row", %{"index" => index}, socket) do
    index = String.to_integer(index)
    editing_mappings = List.delete_at(socket.assigns.editing_mappings, index)

    # Ensure at least one row remains
    editing_mappings =
      if editing_mappings == [] do
        [%{"id" => nil, "source_field" => "", "target_field" => "", "temp_id" => generate_temp_id()}]
      else
        editing_mappings
      end

    {:noreply, assign(socket, :editing_mappings, editing_mappings)}
  end

  @impl true
  def handle_event("update_mapping_field", %{"index" => index, "field" => field, "value" => value}, socket) do
    index = String.to_integer(index)

    editing_mappings =
      List.update_at(socket.assigns.editing_mappings, index, fn mapping ->
        Map.put(mapping, field, value)
      end)

    {:noreply, assign(socket, :editing_mappings, editing_mappings)}
  end

  @impl true
  def handle_event("save_mappings", _params, socket) do
    editing_mappings = socket.assigns.editing_mappings

    # Filter out empty rows
    valid_mappings =
      Enum.filter(editing_mappings, fn m ->
        String.trim(m["source_field"] || "") != "" || String.trim(m["target_field"] || "") != ""
      end)

    # Validate uniqueness
    case validate_mapping_uniqueness(valid_mappings) do
      {:ok, _} ->
        case save_all_mappings(socket, valid_mappings) do
          {:ok, saved_mappings} ->
            socket =
              socket
              |> assign(:mappings, saved_mappings)
              |> assign(:show_mapping_modal, false)
              |> assign(:editing_mappings, [])
              |> assign(:mapping_errors, [])
              |> put_flash(:info, "Mappings saved successfully")

            {:noreply, socket}

          {:error, errors} ->
            {:noreply, assign(socket, :mapping_errors, errors)}
        end

      {:error, errors} ->
        {:noreply, assign(socket, :mapping_errors, errors)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex justify-between items-start">
        <div>
          <div class="flex items-center space-x-3">
            <h1 class="text-2xl font-semibold text-gray-900"><%= @pipeline.name %></h1>
            <span class={[
              "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
              status_color(@pipeline.status)
            ]}>
              <%= @pipeline.status %>
            </span>
          </div>
          <%= if @pipeline.description do %>
            <p class="mt-2 text-sm text-gray-600"><%= @pipeline.description %></p>
          <% end %>
        </div>

        <div class="flex items-center space-x-3">
          <!-- Run Now button - always available for testing -->
          <button
            phx-click="run_now"
            disabled={@running}
            class={[
              "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white",
              if(@running, do: "bg-indigo-400 cursor-not-allowed", else: "bg-indigo-600 hover:bg-indigo-700")
            ]}
          >
            <%= if @running do %>
              <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Running...
            <% else %>
              Run Now
            <% end %>
          </button>

          <%= if @pipeline.status == :inactive do %>
            <button
              phx-click="activate"
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-green-600 hover:bg-green-700"
            >
              Activate
            </button>
            <.link
              navigate={~p"/pipelines/#{@pipeline.id}/edit"}
              class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"
            >
              Edit
            </.link>
            <button
              phx-click="delete"
              data-confirm="Are you sure you want to delete this pipeline?"
              class="inline-flex items-center px-4 py-2 border border-red-300 text-sm font-medium rounded-md shadow-sm text-red-700 bg-white hover:bg-red-50"
            >
              Delete
            </button>
          <% else %>
            <button
              phx-click="deactivate"
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-yellow-600 hover:bg-yellow-700"
            >
              Deactivate
            </button>
          <% end %>
        </div>
      </div>

      <div class="bg-white shadow overflow-hidden sm:rounded-lg">
        <div class="px-4 py-5 sm:px-6">
          <h3 class="text-lg font-medium text-gray-900">Pipeline Configuration</h3>
        </div>
        <div class="border-t border-gray-200">
          <dl>
            <div class="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Type</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2"><%= @pipeline.type %></dd>
            </div>
            <%= if @pipeline.type == :polling do %>
              <div class="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-gray-500">Polling Interval</dt>
                <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                  <%= format_interval(@pipeline.interval_seconds) %>
                </dd>
              </div>
            <% end %>
            <div class="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Source Type</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2"><%= @pipeline.source_type %></dd>
            </div>
            <div class="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Source URL</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                <%= get_in(@pipeline.source_config, ["url"]) || "N/A" %>
              </dd>
            </div>
            <div class="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Persist Data</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                <%= if @pipeline.persist_data, do: "Yes", else: "No" %>
              </dd>
            </div>
            <%= if @pipeline.persist_data && @pipeline.retention_days do %>
              <div class="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-gray-500">Retention Period</dt>
                <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                  <%= @pipeline.retention_days %> days
                </dd>
              </div>
            <% end %>
            <div class="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Sinks</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                <%= if @pipeline.sink_configs && length(@pipeline.sink_configs) > 0 do %>
                  <ul class="list-disc list-inside">
                    <%= for sink <- @pipeline.sink_configs do %>
                      <li><%= sink["type"] %></li>
                    <% end %>
                  </ul>
                <% else %>
                  None configured
                <% end %>
              </dd>
            </div>
          </dl>
        </div>
      </div>

      <!-- Field Mappings Section -->
      <div class="bg-white shadow overflow-hidden sm:rounded-lg">
        <div class="px-4 py-5 sm:px-6 flex justify-between items-center">
          <div>
            <h3 class="text-lg font-medium text-gray-900">Field Mappings</h3>
            <p class="mt-1 text-sm text-gray-500">Configure how source data fields map to target fields</p>
          </div>
          <button
            phx-click="open_mapping_modal"
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700"
          >
            <%= if @mappings == [], do: "Add Mappings", else: "Edit Mappings" %>
          </button>
        </div>
        <div class="border-t border-gray-200">
          <%= if @mappings == [] do %>
            <div class="px-4 py-12 text-center">
              <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
              </svg>
              <h3 class="mt-2 text-sm font-medium text-gray-900">No mappings configured</h3>
              <p class="mt-1 text-sm text-gray-500">
                Add field mappings to define how source data transforms to target fields.
              </p>
            </div>
          <% else %>
            <div class="px-4 py-4">
              <table class="min-w-full divide-y divide-gray-200">
                <thead>
                  <tr>
                    <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Source Field
                    </th>
                    <th class="px-3 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                    </th>
                    <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Target Field
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for mapping <- @mappings do %>
                    <tr>
                      <td class="px-3 py-3 text-sm text-gray-900 font-mono">
                        <%= mapping.source_field %>
                      </td>
                      <td class="px-3 py-3 text-center text-gray-400">
                        &rarr;
                      </td>
                      <td class="px-3 py-3 text-sm text-gray-900 font-mono">
                        <%= mapping.target_field %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      </div>

      <div class="flex justify-start">
        <.link
          navigate={~p"/pipelines"}
          class="text-sm text-indigo-600 hover:text-indigo-500"
        >
          &larr; Back to Pipelines
        </.link>
      </div>
    </div>

    <!-- Mapping Editor Modal -->
    <%= if @show_mapping_modal do %>
      <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
        <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
          <!-- Background overlay -->
          <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" phx-click="close_mapping_modal"></div>

          <!-- Hidden element for vertical centering -->
          <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>

          <!-- Modal panel -->
          <div class="relative z-10 inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-3xl sm:w-full">
            <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
              <div class="sm:flex sm:items-start">
                <div class="w-full">
                  <h3 class="text-lg font-medium text-gray-900 mb-4" id="modal-title">
                    Edit Field Mappings
                  </h3>

                  <!-- Error messages -->
                  <%= if @mapping_errors != [] do %>
                    <div class="mb-4 rounded-md bg-red-50 p-4">
                      <div class="flex">
                        <div class="flex-shrink-0">
                          <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                          </svg>
                        </div>
                        <div class="ml-3">
                          <h3 class="text-sm font-medium text-red-800">Validation errors</h3>
                          <div class="mt-2 text-sm text-red-700">
                            <ul class="list-disc pl-5 space-y-1">
                              <%= for error <- @mapping_errors do %>
                                <li><%= error %></li>
                              <% end %>
                            </ul>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% end %>

                  <!-- Mapping rows header -->
                  <div class="grid grid-cols-11 gap-2 mb-2">
                    <div class="col-span-5 text-sm font-medium text-gray-700">Source Field</div>
                    <div class="col-span-1"></div>
                    <div class="col-span-4 text-sm font-medium text-gray-700">Target Field</div>
                    <div class="col-span-1"></div>
                  </div>

                  <!-- Mapping rows -->
                  <div class="space-y-2 max-h-96 overflow-y-auto">
                    <%= for {mapping, index} <- Enum.with_index(@editing_mappings) do %>
                      <div class="grid grid-cols-11 gap-2 items-center">
                        <div class="col-span-5">
                          <input
                            type="text"
                            value={mapping["source_field"]}
                            phx-blur="update_mapping_field"
                            phx-value-index={index}
                            phx-value-field="source_field"
                            phx-value-value={mapping["source_field"]}
                            placeholder="e.g., data.temperature"
                            class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm font-mono"
                            id={"source-field-#{index}"}
                            phx-hook="MappingInput"
                            data-index={index}
                            data-field="source_field"
                          />
                        </div>
                        <div class="col-span-1 text-center text-gray-400">
                          &rarr;
                        </div>
                        <div class="col-span-4">
                          <input
                            type="text"
                            value={mapping["target_field"]}
                            phx-blur="update_mapping_field"
                            phx-value-index={index}
                            phx-value-field="target_field"
                            phx-value-value={mapping["target_field"]}
                            placeholder="e.g., temperature"
                            class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm font-mono"
                            id={"target-field-#{index}"}
                            phx-hook="MappingInput"
                            data-index={index}
                            data-field="target_field"
                          />
                        </div>
                        <div class="col-span-1">
                          <button
                            type="button"
                            phx-click="remove_mapping_row"
                            phx-value-index={index}
                            class="text-red-600 hover:text-red-800"
                            title="Remove mapping"
                          >
                            <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                            </svg>
                          </button>
                        </div>
                      </div>
                    <% end %>
                  </div>

                  <!-- Add row button -->
                  <div class="mt-4">
                    <button
                      type="button"
                      phx-click="add_mapping_row"
                      class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                    >
                      <svg class="-ml-0.5 mr-2 h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                      </svg>
                      Add Mapping
                    </button>
                  </div>
                </div>
              </div>
            </div>
            <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
              <button
                type="button"
                phx-click="save_mappings"
                class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-indigo-600 text-base font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:ml-3 sm:w-auto sm:text-sm"
              >
                Save Mappings
              </button>
              <button
                type="button"
                phx-click="close_mapping_modal"
                class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp load_pipeline(id, actor) do
    Pipeline
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one(actor: actor)
  end

  defp load_mappings(pipeline_id, actor) do
    DataMapping
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(pipeline_id == ^pipeline_id)
    |> Ash.read!(actor: actor)
  rescue
    _ -> []
  end

  defp update_status(pipeline, status, actor) do
    pipeline
    |> Ash.Changeset.for_update(:update, %{status: status})
    |> Ash.update(actor: actor)
  end

  defp validate_mapping_uniqueness(mappings) do
    source_fields = Enum.map(mappings, & &1["source_field"]) |> Enum.filter(&(&1 != ""))
    target_fields = Enum.map(mappings, & &1["target_field"]) |> Enum.filter(&(&1 != ""))

    errors = []

    # Check for duplicate source fields
    duplicate_sources =
      source_fields
      |> Enum.frequencies()
      |> Enum.filter(fn {_, count} -> count > 1 end)
      |> Enum.map(fn {field, _} -> field end)

    errors =
      if duplicate_sources != [] do
        errors ++ ["Duplicate source fields: #{Enum.join(duplicate_sources, ", ")}"]
      else
        errors
      end

    # Check for duplicate target fields
    duplicate_targets =
      target_fields
      |> Enum.frequencies()
      |> Enum.filter(fn {_, count} -> count > 1 end)
      |> Enum.map(fn {field, _} -> field end)

    errors =
      if duplicate_targets != [] do
        errors ++ ["Duplicate target fields: #{Enum.join(duplicate_targets, ", ")}"]
      else
        errors
      end

    # Check for incomplete mappings
    incomplete =
      Enum.any?(mappings, fn m ->
        source = String.trim(m["source_field"] || "")
        target = String.trim(m["target_field"] || "")
        (source != "" && target == "") || (source == "" && target != "")
      end)

    errors =
      if incomplete do
        errors ++ ["All mappings must have both source and target fields"]
      else
        errors
      end

    if errors == [] do
      {:ok, mappings}
    else
      {:error, errors}
    end
  end

  defp save_all_mappings(socket, new_mappings) do
    pipeline_id = socket.assigns.pipeline.id
    actor = socket.assigns.current_user
    existing_mappings = socket.assigns.mappings

    # Separate into updates, creates, and deletes
    existing_ids = MapSet.new(existing_mappings, & &1.id)
    new_ids = MapSet.new(new_mappings, & &1["id"]) |> MapSet.delete(nil)

    to_delete = MapSet.difference(existing_ids, new_ids) |> MapSet.to_list()
    to_update = Enum.filter(new_mappings, fn m -> m["id"] != nil end)
    to_create = Enum.filter(new_mappings, fn m -> m["id"] == nil && String.trim(m["source_field"] || "") != "" end)

    try do
      # Delete removed mappings
      for id <- to_delete do
        mapping = Enum.find(existing_mappings, &(&1.id == id))
        if mapping, do: Ash.destroy!(mapping, actor: actor)
      end

      # Update existing mappings
      updated =
        for mapping_data <- to_update do
          mapping = Enum.find(existing_mappings, &(&1.id == mapping_data["id"]))

          if mapping do
            mapping
            |> Ash.Changeset.for_update(:update, %{
              source_field: mapping_data["source_field"],
              target_field: mapping_data["target_field"]
            })
            |> Ash.update!(actor: actor)
          end
        end
        |> Enum.filter(& &1)

      # Create new mappings
      created =
        for mapping_data <- to_create do
          DataMapping
          |> Ash.Changeset.for_create(:create, %{
            source_field: mapping_data["source_field"],
            target_field: mapping_data["target_field"],
            pipeline_id: pipeline_id
          })
          |> Ash.create!(actor: actor)
        end

      {:ok, updated ++ created}
    rescue
      e ->
        {:error, [Exception.message(e)]}
    end
  end

  defp generate_temp_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp status_color(:active), do: "bg-green-100 text-green-800"
  defp status_color(:inactive), do: "bg-gray-100 text-gray-800"
  defp status_color(:error), do: "bg-red-100 text-red-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"

  defp format_interval(nil), do: "N/A"
  defp format_interval(seconds) when seconds < 60, do: "#{seconds} seconds"
  defp format_interval(seconds) when seconds < 3600, do: "#{div(seconds, 60)} minutes"
  defp format_interval(seconds), do: "#{div(seconds, 3600)} hours"
end
