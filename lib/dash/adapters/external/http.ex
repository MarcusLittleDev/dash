defmodule Dash.Adapters.External.Http do
  @moduledoc """
  HTTP adapter for fetching data from REST APIs.

  ## Configuration

  ```elixir
  %{
    "url" => "https://api.example.com/data",
    "method" => "GET",  # optional, defaults to GET (GET or POST supported)
    "headers" => %{"Authorization" => "Bearer token"},  # optional
    "body" => %{},  # optional, for POST requests
    "timeout" => 30000,  # optional, defaults to 30 seconds
    "response_path" => "data.items"  # optional, JSON path to extract array
  }
  ```

  ## Authentication

  Authentication is handled via the `headers` configuration. Common patterns:

  ### Bearer Token (OAuth, API tokens)
  ```elixir
  %{
    "url" => "https://api.example.com/data",
    "headers" => %{
      "Authorization" => "Bearer sk_live_1234567890abcdef"
    }
  }
  ```

  ### API Key (custom header)
  ```elixir
  %{
    "url" => "https://api.example.com/data",
    "headers" => %{
      "X-API-Key" => "your-api-key"
    }
  }
  ```

  ### Basic Authentication
  ```elixir
  credentials = Base.encode64("username:password")

  %{
    "url" => "https://api.example.com/data",
    "headers" => %{
      "Authorization" => "Basic \#{credentials}"
    }
  }
  ```

  ### Multiple Auth Headers
  ```elixir
  %{
    "url" => "https://api.example.com/data",
    "headers" => %{
      "X-API-Key" => "key",
      "X-API-Secret" => "secret"
    }
  }
  ```

  ## Response Path

  The `response_path` option allows extracting nested data from the API response.
  For example, if the API returns:

  ```json
  {
    "status": "success",
    "data": {
      "items": [
        {"id": 1, "name": "Item 1"},
        {"id": 2, "name": "Item 2"}
      ]
    }
  }
  ```

  You can use `"response_path" => "data.items"` to extract just the items array.

  ## Examples

      # Fetch from a public API
      config = %{
        "url" => "https://jsonplaceholder.typicode.com/posts"
      }

      {:ok, data, metadata} = Dash.Adapters.External.Http.fetch(config)

      # With authentication
      config = %{
        "url" => "https://api.example.com/data",
        "headers" => %{"Authorization" => "Bearer token123"}
      }

      {:ok, data, metadata} = Dash.Adapters.External.Http.fetch(config)
  """

  @behaviour Dash.Adapters.External

  @impl true
  def fetch(config) do
    start_time = System.monotonic_time(:millisecond)

    with :ok <- validate_config(config),
         {:ok, response} <- make_request(config),
         {:ok, data} <- extract_data(response, config) do
      end_time = System.monotonic_time(:millisecond)

      metadata = %{
        status_code: response.status,
        headers: Map.new(response.headers),
        response_time_ms: end_time - start_time
      }

      {:ok, data, metadata}
    end
  end

  @impl true
  def validate_config(config) when is_map(config) do
    cond do
      not Map.has_key?(config, "url") ->
        {:error, "url is required"}

      not is_binary(config["url"]) or config["url"] == "" ->
        {:error, "url must be a non-empty string"}

      Map.has_key?(config, "method") and config["method"] not in ["GET", "POST"] ->
        {:error, "method must be GET or POST"}

      Map.has_key?(config, "headers") and not is_map(config["headers"]) ->
        {:error, "headers must be a map"}

      Map.has_key?(config, "timeout") and not is_integer(config["timeout"]) ->
        {:error, "timeout must be an integer"}

      true ->
        :ok
    end
  end

  def validate_config(_), do: {:error, "config must be a map"}

  defp make_request(config) do
    url = config["url"]
    method = String.downcase(config["method"] || "get")
    headers = config["headers"] || %{}
    timeout = config["timeout"] || 30_000

    request_opts = [
      headers: Map.to_list(headers),
      receive_timeout: timeout
    ]

    request_opts =
      if method == "post" and Map.has_key?(config, "body") do
        Keyword.put(request_opts, :json, config["body"])
      else
        request_opts
      end

    opts = [method: String.to_atom(method), url: url] ++ request_opts

    case Req.request(opts) do
      {:ok, %{status: status} = response} when status in 200..299 ->
        {:ok, response}

      {:ok, %{status: status} = response} ->
        {:error, "HTTP #{status}: #{inspect(response.body)}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  rescue
    error ->
      {:error, "Request error: #{Exception.message(error)}"}
  end

  defp extract_data(%{body: body}, _config) when is_list(body) do
    {:ok, body}
  end

  defp extract_data(%{body: body}, config) when is_map(body) do
    case config["response_path"] do
      nil ->
        {:ok, [body]}

      path ->
        case get_in_path(body, path) do
          data when is_list(data) -> {:ok, data}
          data when is_map(data) -> {:ok, [data]}
          nil -> {:ok, []}
          _other -> {:error, "response_path did not yield a list or map"}
        end
    end
  end

  defp extract_data(%{body: body}, _config) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_list(decoded) -> {:ok, decoded}
      {:ok, decoded} when is_map(decoded) -> {:ok, [decoded]}
      {:ok, _} -> {:error, "Response body is not an object or array"}
      {:error, reason} -> {:error, "JSON decode failed: #{inspect(reason)}"}
    end
  end

  defp extract_data(_response, _config) do
    {:error, "Unable to extract data from response"}
  end

  defp get_in_path(data, path) when is_binary(path) do
    path
    |> String.split(".")
    |> Enum.reduce(data, fn key, acc ->
      case acc do
        map when is_map(map) -> Map.get(map, key)
        _ -> nil
      end
    end)
  end
end
