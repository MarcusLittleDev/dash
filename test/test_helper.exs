ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Dash.Repo, :manual)

# Create a simple behavior for mocking the External.fetch/2 interface
defmodule Dash.Adapters.ExternalBehaviour do
  @callback fetch(adapter_type :: String.t(), config :: map()) :: 
    {:ok, list(map()), map()} | {:error, term()}
end

# Define mock that implements the behavior
Mox.defmock(Dash.Adapters.ExternalMock, for: Dash.Adapters.ExternalBehaviour)
