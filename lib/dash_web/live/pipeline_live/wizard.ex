defmodule DashWeb.PipelineLive.Wizard do
  use DashWeb, :live_view

  require Ash.Query
  alias Dash.Pipelines.Pipeline

  @steps [:basic_info, :type, :source, :retention, :sinks]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:steps, @steps)
      |> assign(:current_step, :basic_info)
      |> assign(:errors, %{})
      |> assign(:test_data, nil)
      |> assign(:pipeline, nil)
      |> assign(:pipeline_params, default_pipeline_params())

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case load_pipeline(id, socket.assigns.current_user) do
      {:ok, pipeline} ->
        socket =
          socket
          |> assign(:page_title, "Edit Pipeline")
          |> assign(:pipeline, pipeline)
          |> assign(:pipeline_params, pipeline_to_params(pipeline))

        {:noreply, socket}

      {:error, _} ->
        socket =
          socket
          |> put_flash(:error, "Pipeline not found")
          |> push_navigate(to: ~p"/pipelines")

        {:noreply, socket}
    end
  end

  def handle_params(_params, _uri, socket) do
    socket =
      socket
      |> assign(:page_title, "Create Pipeline")
      |> assign(:pipeline, nil)
      |> assign(:pipeline_params, default_pipeline_params())

    {:noreply, socket}
  end

  defp default_pipeline_params do
    %{
      "name" => "",
      "description" => "",
      "type" => "polling",
      "interval_seconds" => 300,
      "source_type" => "http_api",
      "source_config" => %{
        "url" => "",
        "method" => "GET",
        "headers" => %{}
      },
      "persist_data" => true,
      "retention_days" => nil,
      "sink_configs" => []
    }
  end

  defp load_pipeline(id, actor) do
    Pipeline
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one(actor: actor)
  end

  defp pipeline_to_params(pipeline) do
    %{
      "name" => pipeline.name,
      "description" => pipeline.description || "",
      "type" => to_string(pipeline.type),
      "interval_seconds" => pipeline.interval_seconds || 300,
      "source_type" => pipeline.source_type,
      "source_config" => pipeline.source_config || %{"url" => "", "method" => "GET", "headers" => %{}},
      "persist_data" => pipeline.persist_data,
      "retention_days" => pipeline.retention_days,
      "sink_configs" => pipeline.sink_configs || []
    }
  end

  @impl true
  def handle_event("next", params, socket) do
    current_step = socket.assigns.current_step
    pipeline_params = merge_step_params(socket.assigns.pipeline_params, params, current_step)

    case validate_step(current_step, pipeline_params) do
      {:ok, validated_params} ->
        next_step = get_next_step(current_step)

        socket =
          socket
          |> assign(:pipeline_params, validated_params)
          |> assign(:current_step, next_step)
          |> assign(:errors, %{})

        {:noreply, socket}

      {:error, errors} ->
        {:noreply, assign(socket, :errors, errors)}
    end
  end

  @impl true
  def handle_event("back", _params, socket) do
    prev_step = get_prev_step(socket.assigns.current_step)
    {:noreply, assign(socket, :current_step, prev_step)}
  end

  @impl true
  def handle_event("set_interval", %{"seconds" => seconds}, socket) do
    seconds = String.to_integer(seconds)
    pipeline_params = Map.put(socket.assigns.pipeline_params, "interval_seconds", seconds)
    {:noreply, assign(socket, :pipeline_params, pipeline_params)}
  end

  @impl true
  def handle_event("update_auth_type", %{"auth_type" => auth_type}, socket) do
    pipeline_params =
      put_in(socket.assigns.pipeline_params, ["source_config", "auth_type"], auth_type)

    {:noreply, assign(socket, :pipeline_params, pipeline_params)}
  end

  @impl true
  def handle_event("add_header", %{"header_key" => key, "header_value" => value}, socket)
      when key != "" and value != "" do
    headers = get_in(socket.assigns.pipeline_params, ["source_config", "headers"]) || %{}
    headers = Map.put(headers, key, value)

    pipeline_params = put_in(socket.assigns.pipeline_params, ["source_config", "headers"], headers)

    {:noreply, assign(socket, :pipeline_params, pipeline_params)}
  end

  def handle_event("add_header", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("test_connection", _params, socket) do
    config = socket.assigns.pipeline_params["source_config"]

    case Dash.Adapters.External.fetch("http_api", config) do
      {:ok, data, _metadata} ->
        sample = Enum.take(data, 3)
        {:noreply, assign(socket, :test_data, sample)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Connection test failed. Please check your configuration.")
         |> assign(:test_data, nil)}
    end
  end

  @impl true
  def handle_event("toggle_sinks", _params, socket) do
    current_sinks = socket.assigns.pipeline_params["sink_configs"]

    pipeline_params =
      if length(current_sinks) > 0 do
        Map.put(socket.assigns.pipeline_params, "sink_configs", [])
      else
        Map.put(socket.assigns.pipeline_params, "sink_configs", [
          %{"type" => "webhook", "config" => %{"url" => "", "headers" => %{}}}
        ])
      end

    {:noreply, assign(socket, :pipeline_params, pipeline_params)}
  end

  @impl true
  def handle_event("add_sink", _params, socket) do
    sinks = socket.assigns.pipeline_params["sink_configs"]

    new_sink = %{"type" => "webhook", "config" => %{"url" => "", "headers" => %{}}}

    pipeline_params =
      Map.put(socket.assigns.pipeline_params, "sink_configs", sinks ++ [new_sink])

    {:noreply, assign(socket, :pipeline_params, pipeline_params)}
  end

  @impl true
  def handle_event("remove_sink", %{"index" => index}, socket) do
    index = String.to_integer(index)
    sinks = socket.assigns.pipeline_params["sink_configs"]

    pipeline_params =
      Map.put(socket.assigns.pipeline_params, "sink_configs", List.delete_at(sinks, index))

    {:noreply, assign(socket, :pipeline_params, pipeline_params)}
  end

  @impl true
  def handle_event("add_sink_header", params, socket) do
    index = String.to_integer(params["index"])
    key = params["sink_#{index}_header_key"] || ""
    value = params["sink_#{index}_header_value"] || ""

    if key != "" and value != "" do
      sinks = socket.assigns.pipeline_params["sink_configs"]
      sink = Enum.at(sinks, index)

      headers = get_in(sink, ["config", "headers"]) || %{}
      headers = Map.put(headers, key, value)

      sink = put_in(sink, ["config", "headers"], headers)
      sinks = List.replace_at(sinks, index, sink)

      pipeline_params = Map.put(socket.assigns.pipeline_params, "sink_configs", sinks)

      {:noreply, assign(socket, :pipeline_params, pipeline_params)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save", _params, socket) do
    org = socket.assigns.current_org

    cond do
      is_nil(org) ->
        {:noreply, put_flash(socket, :error, "No organization selected")}

      socket.assigns.pipeline && socket.assigns.pipeline.status != :inactive ->
        {:noreply, put_flash(socket, :error, "Cannot edit an active pipeline. Please deactivate it first.")}

      socket.assigns.pipeline ->
        # Update existing pipeline
        case update_pipeline(socket.assigns.pipeline, socket.assigns.pipeline_params, socket.assigns.current_user) do
          {:ok, pipeline} ->
            socket =
              socket
              |> put_flash(:info, "Pipeline '#{pipeline.name}' updated successfully!")
              |> push_navigate(to: ~p"/pipelines/#{pipeline.id}")

            {:noreply, socket}

          {:error, error} ->
            {:noreply, put_flash(socket, :error, "Failed to update pipeline: #{inspect(error)}")}
        end

      true ->
        # Create new pipeline
        case create_pipeline(socket.assigns.pipeline_params, org, socket.assigns.current_user) do
          {:ok, pipeline} ->
            socket =
              socket
              |> put_flash(:info, "Pipeline '#{pipeline.name}' created successfully!")
              |> push_navigate(to: ~p"/pipelines/#{pipeline.id}")

            {:noreply, socket}

          {:error, error} ->
            {:noreply, put_flash(socket, :error, "Failed to create pipeline: #{inspect(error)}")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto">
      <div class="mb-8">
        <h1 class="text-2xl font-semibold text-gray-900">
          <%= if @pipeline, do: "Edit Pipeline", else: "Create Pipeline" %>
        </h1>
        <p class="mt-2 text-sm text-gray-700">
          <%= if @pipeline, do: "Modify your data ingestion pipeline", else: "Set up a new data ingestion pipeline" %>
        </p>
      </div>

      <!-- Progress indicator -->
      <nav class="mb-8" aria-label="Progress">
        <ol class="flex items-center">
          <%= for {step, index} <- Enum.with_index(@steps, 1) do %>
            <li class={["relative", if(index < length(@steps), do: "pr-8 sm:pr-20 flex-1", else: "")]}>
              <% is_current = step == @current_step %>
              <% is_complete = step_index(step) < step_index(@current_step) %>

              <div class="flex items-center">
                <div class={[
                  "relative flex h-8 w-8 items-center justify-center rounded-full",
                  cond do
                    is_current -> "border-2 border-indigo-600 bg-white"
                    is_complete -> "bg-indigo-600"
                    true -> "border-2 border-gray-300 bg-white"
                  end
                ]}>
                  <%= if is_complete do %>
                    <svg class="h-5 w-5 text-white" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                    </svg>
                  <% else %>
                    <span class={[
                      "text-sm font-medium",
                      if(is_current, do: "text-indigo-600", else: "text-gray-500")
                    ]}>
                      <%= index %>
                    </span>
                  <% end %>
                </div>
                <span class={[
                  "ml-4 text-sm font-medium",
                  if(is_current, do: "text-indigo-600", else: "text-gray-500")
                ]}>
                  <%= step_name(step) %>
                </span>
              </div>

              <%= if index < length(@steps) do %>
                <div class="absolute top-4 right-0 w-full h-0.5 bg-gray-200" aria-hidden="true">
                  <%= if is_complete do %>
                    <div class="h-full bg-indigo-600"></div>
                  <% end %>
                </div>
              <% end %>
            </li>
          <% end %>
        </ol>
      </nav>

      <!-- Step content -->
      <div class="bg-white shadow sm:rounded-lg p-6">
        <form phx-submit="next">
          <%= case @current_step do %>
            <% :basic_info -> %>
              <.step_basic_info pipeline_params={@pipeline_params} errors={@errors} />
            <% :type -> %>
              <.step_type pipeline_params={@pipeline_params} errors={@errors} />
            <% :source -> %>
              <.step_source pipeline_params={@pipeline_params} errors={@errors} test_data={@test_data} />
            <% :retention -> %>
              <.step_retention pipeline_params={@pipeline_params} errors={@errors} />
            <% :sinks -> %>
              <.step_sinks pipeline_params={@pipeline_params} errors={@errors} />
          <% end %>

          <!-- Navigation buttons -->
          <div class="mt-8 flex justify-between">
            <div>
              <%= if @current_step != :basic_info do %>
                <button
                  type="button"
                  phx-click="back"
                  class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                >
                  ← Back
                </button>
              <% end %>
            </div>

            <div class="flex gap-3">
              <.link
                navigate={~p"/pipelines"}
                class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
              >
                Cancel
              </.link>

              <%= if @current_step == :sinks do %>
                <button
                  type="button"
                  phx-click="save"
                  class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700"
                >
                  Save & Continue to Mapping →
                </button>
              <% else %>
                <button
                  type="submit"
                  class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700"
                >
                  Next →
                </button>
              <% end %>
            </div>
          </div>
        </form>
      </div>
    </div>
    """
  end

  # Step 1: Basic Information
  defp step_basic_info(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-medium text-gray-900 mb-4">Basic Information</h2>
      <p class="text-sm text-gray-600 mb-6">
        Give your pipeline a name and description
      </p>

      <div class="space-y-6">
        <div>
          <label for="name" class="block text-sm font-medium text-gray-700">
            Name <span class="text-red-500">*</span>
          </label>
          <input
            type="text"
            name="name"
            id="name"
            value={@pipeline_params["name"]}
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            placeholder="e.g., User Data Import"
          />
          <%= if @errors[:name] do %>
            <p class="mt-2 text-sm text-red-600"><%= @errors[:name] %></p>
          <% end %>
        </div>

        <div>
          <label for="description" class="block text-sm font-medium text-gray-700">
            Description
          </label>
          <textarea
            name="description"
            id="description"
            rows="3"
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            placeholder="What does this pipeline do?"
          ><%= @pipeline_params["description"] %></textarea>
        </div>
      </div>
    </div>
    """
  end

  # Step 2: Pipeline Type (placeholder for now)
  defp step_type(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-medium text-gray-900 mb-4">Pipeline Type</h2>
      <p class="text-sm text-gray-600 mb-6">
        Choose how data will be ingested
      </p>

      <div class="grid grid-cols-1 gap-4">
        <div class="relative flex items-start border-2 border-indigo-600 rounded-lg p-4 bg-indigo-50">
          <div class="flex-1">
            <h3 class="text-lg font-medium text-gray-900">Polling</h3>
            <p class="text-sm text-gray-600 mt-1">
              Periodically fetch data from an API on a schedule
            </p>
          </div>
          <div class="ml-3 flex h-5 items-center">
            <svg class="h-6 w-6 text-indigo-600" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
            </svg>
          </div>
        </div>

        <div class="relative flex items-start border-2 border-gray-200 rounded-lg p-4 bg-gray-50 opacity-60">
          <div class="flex-1">
            <h3 class="text-lg font-medium text-gray-900">Webhook</h3>
            <p class="text-sm text-gray-600 mt-1">
              Receive data when it happens via HTTP webhook
            </p>
            <span class="mt-2 inline-flex items-center px-2 py-1 text-xs font-medium text-gray-700 bg-gray-200 rounded">
              Coming Soon
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Step 3: Source Configuration
  defp step_source(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-medium text-gray-900 mb-4">Source Configuration</h2>
      <p class="text-sm text-gray-600 mb-6">
        Configure your data source and polling interval
      </p>

      <div class="space-y-6">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Polling Interval <span class="text-red-500">*</span>
          </label>
          <div class="flex gap-2">
            <input
              type="number"
              name="interval_value"
              value={parse_interval(@pipeline_params["interval_seconds"]).value}
              min="1"
              class="block w-32 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
            <select
              name="interval_unit"
              class="block w-40 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            >
              <option value="seconds" selected={parse_interval(@pipeline_params["interval_seconds"]).unit == "seconds"}>
                Seconds
              </option>
              <option value="minutes" selected={parse_interval(@pipeline_params["interval_seconds"]).unit == "minutes"}>
                Minutes
              </option>
              <option value="hours" selected={parse_interval(@pipeline_params["interval_seconds"]).unit == "hours"}>
                Hours
              </option>
            </select>
          </div>
          <div class="mt-2 flex gap-2">
            <button
              type="button"
              phx-click="set_interval"
              phx-value-seconds="30"
              class="px-2 py-1 text-xs border border-gray-300 rounded hover:bg-gray-50"
            >
              30s
            </button>
            <button
              type="button"
              phx-click="set_interval"
              phx-value-seconds="60"
              class="px-2 py-1 text-xs border border-gray-300 rounded hover:bg-gray-50"
            >
              1min
            </button>
            <button
              type="button"
              phx-click="set_interval"
              phx-value-seconds="300"
              class="px-2 py-1 text-xs border border-gray-300 rounded hover:bg-gray-50"
            >
              5min
            </button>
            <button
              type="button"
              phx-click="set_interval"
              phx-value-seconds="900"
              class="px-2 py-1 text-xs border border-gray-300 rounded hover:bg-gray-50"
            >
              15min
            </button>
            <button
              type="button"
              phx-click="set_interval"
              phx-value-seconds="3600"
              class="px-2 py-1 text-xs border border-gray-300 rounded hover:bg-gray-50"
            >
              1hr
            </button>
          </div>
          <%= if @errors[:interval_seconds] do %>
            <p class="mt-2 text-sm text-red-600"><%= @errors[:interval_seconds] %></p>
          <% end %>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700">
            Source Type
          </label>
          <div class="mt-2 flex items-center gap-2 px-3 py-2 bg-gray-50 border border-gray-200 rounded-md">
            <svg
              class="h-5 w-5 text-gray-400"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"
              />
            </svg>
            <span class="text-sm text-gray-900">HTTP API</span>
            <span class="ml-auto text-xs text-gray-500">(Week 3-4)</span>
          </div>
        </div>

        <div>
          <label for="url" class="block text-sm font-medium text-gray-700">
            API URL <span class="text-red-500">*</span>
          </label>
          <input
            type="url"
            name="url"
            id="url"
            value={get_in(@pipeline_params, ["source_config", "url"])}
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            placeholder="https://api.example.com/data"
          />
          <%= if @errors[:url] do %>
            <p class="mt-2 text-sm text-red-600"><%= @errors[:url] %></p>
          <% end %>
        </div>

        <div>
          <label for="method" class="block text-sm font-medium text-gray-700">
            HTTP Method
          </label>
          <select
            name="method"
            id="method"
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          >
            <option value="GET" selected={get_in(@pipeline_params, ["source_config", "method"]) == "GET"}>
              GET
            </option>
            <option value="POST" selected={get_in(@pipeline_params, ["source_config", "method"]) == "POST"}>
              POST
            </option>
            <option value="PUT" selected={get_in(@pipeline_params, ["source_config", "method"]) == "PUT"}>
              PUT
            </option>
          </select>
        </div>

        <div>
          <label for="auth_type" class="block text-sm font-medium text-gray-700">
            Authentication
          </label>
          <select
            name="auth_type"
            id="auth_type"
            phx-change="update_auth_type"
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          >
            <option value="none" selected={get_in(@pipeline_params, ["source_config", "auth_type"]) == "none"}>
              None
            </option>
            <option value="bearer" selected={get_in(@pipeline_params, ["source_config", "auth_type"]) == "bearer"}>
              Bearer Token
            </option>
            <option value="api_key" selected={get_in(@pipeline_params, ["source_config", "auth_type"]) == "api_key"}>
              API Key
            </option>
          </select>
        </div>

        <%= if get_in(@pipeline_params, ["source_config", "auth_type"]) in ["bearer", "api_key"] do %>
          <div>
            <label for="auth_token" class="block text-sm font-medium text-gray-700">
              <%= if get_in(@pipeline_params, ["source_config", "auth_type"]) == "bearer",
                do: "Bearer Token",
                else: "API Key" %> <span class="text-red-500">*</span>
            </label>
            <input
              type="password"
              name="auth_token"
              id="auth_token"
              value={get_in(@pipeline_params, ["source_config", "auth_token"])}
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              placeholder={
                if get_in(@pipeline_params, ["source_config", "auth_type"]) == "bearer",
                  do: "Enter bearer token",
                  else: "Enter API key"
              }
            />
          </div>
        <% end %>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Custom Headers (optional)
          </label>
          <div class="space-y-2">
            <%= for {key, value} <- get_in(@pipeline_params, ["source_config", "headers"]) || %{} do %>
              <div class="flex gap-2">
                <input
                  type="text"
                  value={key}
                  readonly
                  class="block w-1/3 rounded-md border-gray-300 bg-gray-50 shadow-sm sm:text-sm"
                />
                <input
                  type="text"
                  value={value}
                  readonly
                  class="block flex-1 rounded-md border-gray-300 bg-gray-50 shadow-sm sm:text-sm"
                />
              </div>
            <% end %>
            <div class="flex gap-2">
              <input
                type="text"
                name="header_key"
                placeholder="Header name"
                class="block w-1/3 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              />
              <input
                type="text"
                name="header_value"
                placeholder="Header value"
                class="block flex-1 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              />
              <button
                type="button"
                phx-click="add_header"
                class="px-3 py-2 text-sm border border-gray-300 rounded-md hover:bg-gray-50"
              >
                Add
              </button>
            </div>
          </div>
        </div>

        <div>
          <button
            type="button"
            phx-click="test_connection"
            class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
          >
            <svg
              class="-ml-1 mr-2 h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M5 13l4 4L19 7"
              />
            </svg>
            Test Connection
          </button>

          <%= if @test_data do %>
            <div class="mt-4 p-4 bg-green-50 border border-green-200 rounded-md">
              <h4 class="text-sm font-medium text-green-900 mb-2">✓ Connection successful</h4>
              <p class="text-xs text-green-700 mb-2">Sample data preview:</p>
              <pre class="text-xs bg-white p-2 rounded border border-green-200 overflow-x-auto"><%= Jason.encode!(@test_data, pretty: true) |> String.slice(0, 500) %><%= if String.length(Jason.encode!(@test_data)) > 500, do: "..." %></pre>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Step 4: Data Retention
  defp step_retention(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-medium text-gray-900 mb-4">Data Retention</h2>
      <p class="text-sm text-gray-600 mb-6">
        Configure how long to keep pipeline data
      </p>

      <div class="space-y-6">
        <div>
          <div class="flex items-start">
            <div class="flex items-center h-5">
              <input
                type="checkbox"
                name="persist_data"
                id="persist_data"
                checked={@pipeline_params["persist_data"]}
                class="h-4 w-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500"
              />
            </div>
            <div class="ml-3">
              <label for="persist_data" class="text-sm font-medium text-gray-700">
                Store data in TimescaleDB
              </label>
              <p class="text-xs text-gray-500 mt-1">
                Uncheck to only cache in memory and broadcast to dashboards
              </p>
            </div>
          </div>
        </div>

        <%= if @pipeline_params["persist_data"] do %>
          <div class="ml-7 space-y-4">
            <div>
              <label class="flex items-center">
                <input
                  type="radio"
                  name="retention_type"
                  value="forever"
                  checked={is_nil(@pipeline_params["retention_days"])}
                  class="h-4 w-4 text-indigo-600 border-gray-300 focus:ring-indigo-500"
                />
                <span class="ml-2 text-sm text-gray-700">Keep forever</span>
              </label>
            </div>

            <div>
              <label class="flex items-start">
                <input
                  type="radio"
                  name="retention_type"
                  value="limited"
                  checked={not is_nil(@pipeline_params["retention_days"])}
                  class="mt-1 h-4 w-4 text-indigo-600 border-gray-300 focus:ring-indigo-500"
                />
                <div class="ml-2 flex-1">
                  <span class="text-sm text-gray-700">Delete after</span>
                  <div class="mt-2 flex items-center gap-2">
                    <input
                      type="number"
                      name="retention_days"
                      value={@pipeline_params["retention_days"]}
                      min="1"
                      placeholder="30"
                      class="block w-24 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                    />
                    <span class="text-sm text-gray-700">days</span>
                  </div>
                </div>
              </label>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Step 5: Pipeline Sinks
  defp step_sinks(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-medium text-gray-900 mb-4">Pipeline Sinks</h2>
      <p class="text-sm text-gray-600 mb-6">
        Send data to external destinations (optional)
      </p>

      <div class="space-y-6">
        <div>
          <div class="flex items-start">
            <div class="flex items-center h-5">
              <input
                type="checkbox"
                name="enable_sinks"
                id="enable_sinks"
                checked={length(@pipeline_params["sink_configs"]) > 0}
                phx-click="toggle_sinks"
                class="h-4 w-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500"
              />
            </div>
            <div class="ml-3">
              <label for="enable_sinks" class="text-sm font-medium text-gray-700">
                Send data to external destinations
              </label>
              <p class="text-xs text-gray-500 mt-1">
                Configure webhooks or other outputs to receive pipeline data
              </p>
            </div>
          </div>
        </div>

        <%= if length(@pipeline_params["sink_configs"]) > 0 do %>
          <div class="space-y-4">
            <%= for {sink, index} <- Enum.with_index(@pipeline_params["sink_configs"]) do %>
              <div class="border border-gray-200 rounded-lg p-4 bg-gray-50">
                <div class="flex justify-between items-start mb-3">
                  <h4 class="text-sm font-medium text-gray-900">Sink <%= index + 1 %></h4>
                  <button
                    type="button"
                    phx-click="remove_sink"
                    phx-value-index={index}
                    class="text-sm text-red-600 hover:text-red-800"
                  >
                    Remove
                  </button>
                </div>

                <div class="space-y-3">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Type</label>
                    <select
                      name={"sink_#{index}_type"}
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                    >
                      <option value="webhook" selected={sink["type"] == "webhook"}>Webhook</option>
                      <option value="s3" disabled>S3/R2 (Coming in Phase 2)</option>
                      <option value="database" disabled>Database (Coming in Phase 2)</option>
                    </select>
                  </div>

                  <%= if sink["type"] == "webhook" do %>
                    <div>
                      <label class="block text-sm font-medium text-gray-700">
                        Webhook URL <span class="text-red-500">*</span>
                      </label>
                      <input
                        type="url"
                        name={"sink_#{index}_url"}
                        value={get_in(sink, ["config", "url"])}
                        placeholder="https://webhook.site/..."
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                      />
                    </div>

                    <div>
                      <label class="block text-sm text-gray-700 mb-2">Headers (optional)</label>
                      <%= for {key, value} <- get_in(sink, ["config", "headers"]) || %{} do %>
                        <div class="flex gap-2 mb-2">
                          <input
                            type="text"
                            value={key}
                            readonly
                            class="block w-1/3 rounded-md border-gray-300 bg-white shadow-sm sm:text-sm"
                          />
                          <input
                            type="text"
                            value={value}
                            readonly
                            class="block flex-1 rounded-md border-gray-300 bg-white shadow-sm sm:text-sm"
                          />
                        </div>
                      <% end %>
                      <div class="flex gap-2">
                        <input
                          type="text"
                          name={"sink_#{index}_header_key"}
                          placeholder="Header name"
                          class="block w-1/3 rounded-md border-gray-300 shadow-sm sm:text-sm"
                        />
                        <input
                          type="text"
                          name={"sink_#{index}_header_value"}
                          placeholder="Header value"
                          class="block flex-1 rounded-md border-gray-300 shadow-sm sm:text-sm"
                        />
                        <button
                          type="button"
                          phx-click="add_sink_header"
                          phx-value-index={index}
                          class="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-white"
                        >
                          Add
                        </button>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>

            <button
              type="button"
              phx-click="add_sink"
              class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
            >
              <svg
                class="-ml-1 mr-2 h-4 w-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              Add Another Sink
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper functions
  defp step_index(step), do: Enum.find_index(@steps, &(&1 == step))

  defp step_name(:basic_info), do: "Basic Info"
  defp step_name(:type), do: "Type"
  defp step_name(:source), do: "Source"
  defp step_name(:retention), do: "Retention"
  defp step_name(:sinks), do: "Sinks"

  defp get_next_step(current_step) do
    current_index = step_index(current_step)
    Enum.at(@steps, current_index + 1) || current_step
  end

  defp get_prev_step(current_step) do
    current_index = step_index(current_step)
    if current_index > 0, do: Enum.at(@steps, current_index - 1), else: current_step
  end

  defp validate_step(:basic_info, params) do
    errors = %{}

    errors =
      if is_nil(params["name"]) or String.trim(params["name"]) == "" do
        Map.put(errors, :name, "Name is required")
      else
        errors
      end

    if map_size(errors) == 0 do
      {:ok, params}
    else
      {:error, errors}
    end
  end

  defp validate_step(:source, params) do
    errors = %{}

    interval_seconds = params["interval_seconds"] || 300

    errors =
      if interval_seconds < 30 or interval_seconds > 86400 do
        Map.put(errors, :interval_seconds, "Interval must be between 30 seconds and 24 hours")
      else
        errors
      end

    url = get_in(params, ["source_config", "url"])

    errors =
      if is_nil(url) or String.trim(url) == "" do
        Map.put(errors, :url, "URL is required")
      else
        errors
      end

    if map_size(errors) == 0 do
      {:ok, params}
    else
      {:error, errors}
    end
  end

  defp validate_step(_step, params), do: {:ok, params}

  defp parse_interval(nil), do: %{value: 5, unit: "minutes"}
  defp parse_interval(seconds) when seconds < 60, do: %{value: seconds, unit: "seconds"}
  defp parse_interval(seconds) when seconds < 3600, do: %{value: div(seconds, 60), unit: "minutes"}
  defp parse_interval(seconds), do: %{value: div(seconds, 3600), unit: "hours"}

  defp merge_step_params(pipeline_params, params, :source) do
    interval_seconds =
      case {params["interval_value"], params["interval_unit"]} do
        {value, "seconds"} when value != nil ->
          String.to_integer(value)

        {value, "minutes"} when value != nil ->
          String.to_integer(value) * 60

        {value, "hours"} when value != nil ->
          String.to_integer(value) * 3600

        _ ->
          pipeline_params["interval_seconds"] || 300
      end

    source_config =
      pipeline_params["source_config"]
      |> Map.put("url", params["url"] || "")
      |> Map.put("method", params["method"] || "GET")
      |> Map.put("auth_type", params["auth_type"] || "none")

    source_config =
      if params["auth_token"] do
        Map.put(source_config, "auth_token", params["auth_token"])
      else
        source_config
      end

    pipeline_params
    |> Map.put("interval_seconds", interval_seconds)
    |> Map.put("source_config", source_config)
  end

  defp merge_step_params(pipeline_params, params, :retention) do
    persist_data = params["persist_data"] == "on" || params["persist_data"] == true

    retention_days =
      case params["retention_type"] do
        "limited" ->
          case params["retention_days"] do
            nil -> nil
            "" -> nil
            days -> String.to_integer(days)
          end

        _ ->
          nil
      end

    pipeline_params
    |> Map.put("persist_data", persist_data)
    |> Map.put("retention_days", retention_days)
  end

  defp merge_step_params(pipeline_params, params, _step) do
    Map.merge(pipeline_params, params)
  end

  defp create_pipeline(params, org, actor) do
    Pipeline
    |> Ash.Changeset.for_create(:create, %{
      name: params["name"],
      description: params["description"],
      type: String.to_atom(params["type"] || "polling"),
      status: :inactive,
      interval_seconds: params["interval_seconds"],
      source_type: params["source_type"],
      source_config: params["source_config"],
      persist_data: params["persist_data"],
      retention_days: params["retention_days"],
      sink_configs: params["sink_configs"] || [],
      organization_id: org.id
    })
    |> Ash.create(actor: actor)
  end

  defp update_pipeline(pipeline, params, actor) do
    pipeline
    |> Ash.Changeset.for_update(:update, %{
      name: params["name"],
      description: params["description"],
      type: String.to_atom(params["type"] || "polling"),
      interval_seconds: params["interval_seconds"],
      source_type: params["source_type"],
      source_config: params["source_config"],
      persist_data: params["persist_data"],
      retention_days: params["retention_days"],
      sink_configs: params["sink_configs"] || []
    })
    |> Ash.update(actor: actor)
  end
end
