defmodule Dash.Pipelines do
  @moduledoc """
  The Pipelines domain.

  Manages data pipelines for ingesting, transforming, and storing time-series data
  from external sources (HTTP polling, webhooks, etc.).
  """

  use Ash.Domain

  resources do
    resource Dash.Pipelines.Pipeline
    resource Dash.Pipelines.PipelineEvent
    resource Dash.Pipelines.DataMapping
    resource Dash.Pipelines.ExecutionLog
  end
end
