defmodule Dash.Dashboards do
  @moduledoc """
  The Dashboards domain.

  Manages dashboards and widgets for visualizing pipeline data in real-time.
  Dashboards contain configurable widgets (tables, charts, stat cards) that
  display data from pipelines via PubSub subscriptions.
  """

  use Ash.Domain

  resources do
    resource Dash.Dashboards.Dashboard
    resource Dash.Dashboards.Widget
  end
end
