defmodule Dash.Pipelines.DataMapper do
  @moduledoc """
  Transforms raw source data according to pipeline data mappings.

  The DataMapper takes raw records from external sources and applies field-level
  transformations based on the pipeline's DataMapping configurations. For Week 3-4,
  this focuses on simple field remapping (extracting source fields and renaming them
  to target fields).

  ## Workflow

  1. Load data mappings for the pipeline
  2. For each source record, extract values from source fields (supporting nested paths)
  3. Map values to target field names
  4. Validate required fields are present
  5. Return transformed records ready for storage

  ## Example

      mappings = [
        %{source_field: "data.temp", target_field: "temperature", required: true},
        %{source_field: "timestamp", target_field: "recorded_at", required: true},
        %{source_field: "location.city", target_field: "city", required: false}
      ]

      source_data = [
        %{
          "data" => %{"temp" => 72.5},
          "timestamp" => "2024-01-31T10:00:00Z",
          "location" => %{"city" => "Portland"}
        }
      ]

      {:ok, transformed} = DataMapper.transform(source_data, mappings)
      # => {:ok, [%{
      #   "temperature" => 72.5,
      #   "recorded_at" => "2024-01-31T10:00:00Z",
      #   "city" => "Portland"
      # }]}
  """

  require Logger

  @doc """
  Transforms a list of source records according to the provided mappings.

  Returns `{:ok, transformed_records}` on success.
  Returns `{:error, reason}` if transformation fails.
  """
  @spec transform(list(map()), list(map())) :: {:ok, list(map())} | {:error, term()}
  def transform(source_records, mappings) when is_list(source_records) and is_list(mappings) do
    try do
      transformed =
        Enum.map(source_records, fn record ->
          transform_record(record, mappings)
        end)

      if Enum.all?(transformed, fn result -> match?({:ok, _}, result) end) do
        records = Enum.map(transformed, fn {:ok, record} -> record end)
        {:ok, records}
      else
        errors =
          transformed
          |> Enum.filter(fn result -> match?({:error, _}, result) end)
          |> Enum.map(fn {:error, reason} -> reason end)

        {:error, "Transformation failed for #{length(errors)} record(s): #{inspect(errors)}"}
      end
    rescue
      error ->
        {:error, "Transformation error: #{Exception.message(error)}"}
    end
  end

  def transform(_, _), do: {:error, "Invalid input: expected lists for both records and mappings"}

  @doc """
  Transforms a single source record according to the provided mappings.

  Returns `{:ok, transformed_record}` on success.
  Returns `{:error, reason}` if required fields are missing or extraction fails.
  """
  @spec transform_record(map(), list(map())) :: {:ok, map()} | {:error, String.t()}
  def transform_record(source_record, mappings) when is_map(source_record) do
    result =
      Enum.reduce_while(mappings, %{}, fn mapping, acc ->
        source_field = Map.get(mapping, :source_field) || Map.get(mapping, "source_field")
        target_field = Map.get(mapping, :target_field) || Map.get(mapping, "target_field")
        required = Map.get(mapping, :required) || Map.get(mapping, "required") || false

        cond do
          is_nil(source_field) or source_field == "" ->
            {:halt, {:error, "Mapping missing source_field"}}

          is_nil(target_field) or target_field == "" ->
            {:halt, {:error, "Mapping missing target_field"}}

          true ->
            process_mapping(source_record, source_field, target_field, required, acc)
        end
      end)

    case result do
      {:error, _} = error -> error
      transformed_record -> {:ok, transformed_record}
    end
  end

  defp process_mapping(source_record, source_field, target_field, required, acc) do
    case extract_field(source_record, source_field) do
      {:ok, value} ->
        {:cont, Map.put(acc, target_field, value)}

      {:error, :not_found} when required ->
        {:halt, {:error, "Required field '#{source_field}' not found in source data"}}

      {:error, :not_found} ->
        {:cont, acc}

      {:error, reason} ->
        {:halt, {:error, "Failed to extract '#{source_field}': #{reason}"}}
    end
  end

  @doc """
  Extracts a value from a source record using a field path.

  Supports nested paths like "data.temperature" or simple field names like "temperature".

  Returns `{:ok, value}` if the field exists.
  Returns `{:error, :not_found}` if the field doesn't exist.
  """
  @spec extract_field(map(), String.t()) :: {:ok, term()} | {:error, :not_found | String.t()}
  def extract_field(source, field_path) when is_map(source) and is_binary(field_path) do
    keys = String.split(field_path, ".")

    result =
      Enum.reduce_while(keys, source, fn key, current ->
        cond do
          is_map(current) and Map.has_key?(current, key) ->
            {:cont, Map.get(current, key)}

          is_map(current) and Map.has_key?(current, String.to_atom(key)) ->
            {:cont, Map.get(current, String.to_atom(key))}

          true ->
            {:halt, :not_found}
        end
      end)

    case result do
      :not_found -> {:error, :not_found}
      value -> {:ok, value}
    end
  end

  def extract_field(_, _), do: {:error, "Invalid source or field path"}

  @doc """
  Loads data mappings for a pipeline.

  Returns a list of mapping structs or maps with source_field, target_field, and required keys.
  """
  @spec load_mappings_for_pipeline(Ash.Resource.record()) :: {:ok, list(map())} | {:error, term()}
  def load_mappings_for_pipeline(pipeline) do
    case Ash.load(pipeline, :data_mappings) do
      {:ok, loaded_pipeline} ->
        mappings =
          loaded_pipeline.data_mappings
          |> Enum.map(fn mapping ->
            %{
              source_field: mapping.source_field,
              target_field: mapping.target_field,
              required: mapping.required,
              transformation_type: mapping.transformation_type
            }
          end)

        {:ok, mappings}

      {:error, reason} ->
        Logger.error("Failed to load mappings for pipeline: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
