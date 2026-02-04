defmodule Dash.Dashboards.PubSub do
  @moduledoc """
  PubSub integration for dashboard real-time updates.

  Provides subscription and broadcast functions for:
  - Widget data updates (when pipeline data changes)
  - Dashboard events (widget added/removed/updated)
  - Pipeline data streams (for widgets watching a pipeline)
  """

  alias Phoenix.PubSub

  @pubsub Dash.PubSub

  # Topics

  defp widget_topic(widget_id), do: "widget:#{widget_id}"
  defp dashboard_topic(dashboard_id), do: "dashboard:#{dashboard_id}"
  defp pipeline_topic(pipeline_id), do: "pipeline:#{pipeline_id}"

  # Subscriptions

  @doc """
  Subscribe to updates for a specific widget.

  Messages received:
  - `{:widget_data, widget_id, data}` - New data for the widget
  - `{:widget_config_updated, widget_id, config}` - Widget configuration changed
  """
  def subscribe_widget(widget_id) do
    PubSub.subscribe(@pubsub, widget_topic(widget_id))
  end

  @doc """
  Subscribe to dashboard-level events.

  Messages received:
  - `{:widget_added, widget}` - A new widget was added
  - `{:widget_removed, widget_id}` - A widget was removed
  - `{:dashboard_updated, dashboard}` - Dashboard settings changed
  """
  def subscribe_dashboard(dashboard_id) do
    PubSub.subscribe(@pubsub, dashboard_topic(dashboard_id))
  end

  @doc """
  Subscribe to all data from a pipeline.

  Messages received:
  - `{:pipeline_data, pipeline_id, data}` - New data from pipeline execution
  """
  def subscribe_pipeline(pipeline_id) do
    PubSub.subscribe(@pubsub, pipeline_topic(pipeline_id))
  end

  # Unsubscriptions

  def unsubscribe_widget(widget_id) do
    PubSub.unsubscribe(@pubsub, widget_topic(widget_id))
  end

  def unsubscribe_dashboard(dashboard_id) do
    PubSub.unsubscribe(@pubsub, dashboard_topic(dashboard_id))
  end

  def unsubscribe_pipeline(pipeline_id) do
    PubSub.unsubscribe(@pubsub, pipeline_topic(pipeline_id))
  end

  # Broadcasts

  @doc """
  Broadcast new data to a specific widget's subscribers.
  """
  def broadcast_widget_data(widget_id, data) do
    PubSub.broadcast(@pubsub, widget_topic(widget_id), {:widget_data, widget_id, data})
  end

  @doc """
  Broadcast widget configuration update.
  """
  def broadcast_widget_config_updated(widget_id, config) do
    PubSub.broadcast(@pubsub, widget_topic(widget_id), {:widget_config_updated, widget_id, config})
  end

  @doc """
  Broadcast that a widget was added to a dashboard.
  """
  def broadcast_widget_added(dashboard_id, widget) do
    PubSub.broadcast(@pubsub, dashboard_topic(dashboard_id), {:widget_added, widget})
  end

  @doc """
  Broadcast that a widget was removed from a dashboard.
  """
  def broadcast_widget_removed(dashboard_id, widget_id) do
    PubSub.broadcast(@pubsub, dashboard_topic(dashboard_id), {:widget_removed, widget_id})
  end

  @doc """
  Broadcast dashboard settings update.
  """
  def broadcast_dashboard_updated(dashboard_id, dashboard) do
    PubSub.broadcast(@pubsub, dashboard_topic(dashboard_id), {:dashboard_updated, dashboard})
  end

  @doc """
  Broadcast new pipeline data to all subscribers.

  This is called by the Pipeline Executor when a pipeline completes successfully.
  """
  def broadcast_pipeline_data(pipeline_id, data) do
    PubSub.broadcast(@pubsub, pipeline_topic(pipeline_id), {:pipeline_data, pipeline_id, data})
  end

  @doc """
  Broadcast pipeline data to all widgets watching this pipeline.

  This finds all widgets configured for the given pipeline and broadcasts
  data to each widget's topic, also updating the DataServer cache.
  """
  def broadcast_to_widgets(pipeline_id, data) do
    require Ash.Query

    # Find all widgets watching this pipeline
    widgets =
      Dash.Dashboards.Widget
      |> Ash.Query.for_read(:for_pipeline, %{pipeline_id: pipeline_id})
      |> Ash.read!(authorize?: false)

    Enum.each(widgets, fn widget ->
      # Update ETS cache
      Dash.Dashboards.DataServer.push_data(widget.id, data)

      # Broadcast to widget subscribers
      broadcast_widget_data(widget.id, data)
    end)

    # Also broadcast on pipeline topic for any direct subscribers
    broadcast_pipeline_data(pipeline_id, data)
  end
end
