defmodule Dash.Adapters.External do
  @moduledoc """
  Behavior for external API adapters.

  External adapters define how to fetch data from external sources (HTTP APIs,
  GraphQL, gRPC, etc.). Each adapter implements the `fetch/1` callback to
  retrieve data based on the source configuration.

  ## Available Adapters

  - `Dash.Adapters.External.Http` - HTTP/REST API adapter

  ## Future Adapters

  - GraphQL
  - gRPC
  - WebSocket
  - MQTT
  """

  @doc """
  Fetches data from the external source using the provided configuration.

  Returns `{:ok, data, metadata}` on success where:
  - `data` is a list of maps representing the fetched records
  - `metadata` is a map containing response information (headers, timing, etc.)

  Returns `{:error, reason}` on failure.
  """
  @callback fetch(config :: map()) :: {:ok, list(map()), map()} | {:error, term()}

  @doc """
  Validates the source configuration for this adapter.

  Returns `:ok` if valid, `{:error, reason}` otherwise.
  """
  @callback validate_config(config :: map()) :: :ok | {:error, String.t()}

  @doc """
  Returns the adapter module for the given adapter type.
  """
  @spec get_adapter(String.t()) :: module() | nil
  def get_adapter("http"), do: Dash.Adapters.External.Http
  def get_adapter(_), do: nil

  @doc """
  Fetches data using the appropriate adapter for the given type.
  """
  @spec fetch(String.t(), map()) :: {:ok, list(map()), map()} | {:error, term()}
  def fetch(adapter_type, config) do
    case get_adapter(adapter_type) do
      nil ->
        {:error, "Unknown adapter type: #{adapter_type}"}

      adapter ->
        adapter.fetch(config)
    end
  end

  @doc """
  Validates configuration using the appropriate adapter for the given type.
  """
  @spec validate_config(String.t(), map()) :: :ok | {:error, String.t()}
  def validate_config(adapter_type, config) do
    case get_adapter(adapter_type) do
      nil ->
        {:error, "Unknown adapter type: #{adapter_type}"}

      adapter ->
        adapter.validate_config(config)
    end
  end
end
