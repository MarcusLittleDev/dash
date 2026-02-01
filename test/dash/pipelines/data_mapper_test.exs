defmodule Dash.Pipelines.DataMapperTest do
  use ExUnit.Case, async: true

  alias Dash.Pipelines.DataMapper

  describe "extract_field/2" do
    test "extracts top-level field with string key" do
      source = %{"temperature" => 72.5}
      assert {:ok, 72.5} = DataMapper.extract_field(source, "temperature")
    end

    test "extracts top-level field with atom key" do
      source = %{temperature: 72.5}
      assert {:ok, 72.5} = DataMapper.extract_field(source, "temperature")
    end

    test "extracts nested field with string keys" do
      source = %{"data" => %{"temp" => 72.5}}
      assert {:ok, 72.5} = DataMapper.extract_field(source, "data.temp")
    end

    test "extracts deeply nested field" do
      source = %{
        "sensor" => %{
          "readings" => %{
            "temperature" => 72.5
          }
        }
      }

      assert {:ok, 72.5} = DataMapper.extract_field(source, "sensor.readings.temperature")
    end

    test "extracts nested field with mixed string/atom keys" do
      source = %{"data" => %{temp: 72.5}}
      assert {:ok, 72.5} = DataMapper.extract_field(source, "data.temp")
    end

    test "returns error when field not found" do
      source = %{"temperature" => 72.5}
      assert {:error, :not_found} = DataMapper.extract_field(source, "humidity")
    end

    test "returns error when nested field not found" do
      source = %{"data" => %{"temp" => 72.5}}
      assert {:error, :not_found} = DataMapper.extract_field(source, "data.humidity")
    end

    test "returns error when intermediate path not found" do
      source = %{"data" => %{"temp" => 72.5}}
      assert {:error, :not_found} = DataMapper.extract_field(source, "sensor.temp")
    end

    test "handles null/nil values" do
      source = %{"temperature" => nil}
      assert {:ok, nil} = DataMapper.extract_field(source, "temperature")
    end

    test "handles various data types" do
      source = %{
        "string" => "value",
        "number" => 42,
        "float" => 3.14,
        "boolean" => true,
        "list" => [1, 2, 3],
        "map" => %{"nested" => "data"}
      }

      assert {:ok, "value"} = DataMapper.extract_field(source, "string")
      assert {:ok, 42} = DataMapper.extract_field(source, "number")
      assert {:ok, 3.14} = DataMapper.extract_field(source, "float")
      assert {:ok, true} = DataMapper.extract_field(source, "boolean")
      assert {:ok, [1, 2, 3]} = DataMapper.extract_field(source, "list")
      assert {:ok, %{"nested" => "data"}} = DataMapper.extract_field(source, "map")
    end
  end

  describe "transform_record/2" do
    test "transforms record with simple field mappings" do
      source = %{
        "temp" => 72.5,
        "humidity" => 45
      }

      mappings = [
        %{source_field: "temp", target_field: "temperature", required: false},
        %{source_field: "humidity", target_field: "humidity_percent", required: false}
      ]

      assert {:ok, result} = DataMapper.transform_record(source, mappings)
      assert result["temperature"] == 72.5
      assert result["humidity_percent"] == 45
    end

    test "transforms record with nested source fields" do
      source = %{
        "data" => %{
          "temp" => 72.5,
          "pressure" => 1013.25
        },
        "metadata" => %{
          "timestamp" => "2024-01-31T10:00:00Z"
        }
      }

      mappings = [
        %{source_field: "data.temp", target_field: "temperature", required: true},
        %{source_field: "data.pressure", target_field: "pressure", required: true},
        %{source_field: "metadata.timestamp", target_field: "recorded_at", required: true}
      ]

      assert {:ok, result} = DataMapper.transform_record(source, mappings)
      assert result["temperature"] == 72.5
      assert result["pressure"] == 1013.25
      assert result["recorded_at"] == "2024-01-31T10:00:00Z"
    end

    test "skips optional fields that don't exist" do
      source = %{"temp" => 72.5}

      mappings = [
        %{source_field: "temp", target_field: "temperature", required: true},
        %{source_field: "humidity", target_field: "humidity", required: false}
      ]

      assert {:ok, result} = DataMapper.transform_record(source, mappings)
      assert result["temperature"] == 72.5
      refute Map.has_key?(result, "humidity")
    end

    test "returns error when required field is missing" do
      source = %{"temp" => 72.5}

      mappings = [
        %{source_field: "temp", target_field: "temperature", required: true},
        %{source_field: "humidity", target_field: "humidity", required: true}
      ]

      assert {:error, reason} = DataMapper.transform_record(source, mappings)
      assert reason =~ "Required field 'humidity' not found"
    end

    test "handles empty mappings" do
      source = %{"temp" => 72.5}
      mappings = []

      assert {:ok, result} = DataMapper.transform_record(source, mappings)
      assert result == %{}
    end

    test "preserves value types during transformation" do
      source = %{
        "string_val" => "text",
        "int_val" => 42,
        "float_val" => 3.14,
        "bool_val" => true,
        "null_val" => nil,
        "array_val" => [1, 2, 3],
        "map_val" => %{"key" => "value"}
      }

      mappings = [
        %{source_field: "string_val", target_field: "s", required: false},
        %{source_field: "int_val", target_field: "i", required: false},
        %{source_field: "float_val", target_field: "f", required: false},
        %{source_field: "bool_val", target_field: "b", required: false},
        %{source_field: "null_val", target_field: "n", required: false},
        %{source_field: "array_val", target_field: "a", required: false},
        %{source_field: "map_val", target_field: "m", required: false}
      ]

      assert {:ok, result} = DataMapper.transform_record(source, mappings)
      assert result["s"] == "text"
      assert result["i"] == 42
      assert result["f"] == 3.14
      assert result["b"] == true
      assert result["n"] == nil
      assert result["a"] == [1, 2, 3]
      assert result["m"] == %{"key" => "value"}
    end
  end

  describe "transform/2" do
    test "transforms multiple records successfully" do
      source_records = [
        %{"temp" => 72.5, "humidity" => 45},
        %{"temp" => 68.0, "humidity" => 50},
        %{"temp" => 75.2, "humidity" => 42}
      ]

      mappings = [
        %{source_field: "temp", target_field: "temperature", required: true},
        %{source_field: "humidity", target_field: "humidity_percent", required: true}
      ]

      assert {:ok, results} = DataMapper.transform(source_records, mappings)
      assert length(results) == 3

      assert Enum.at(results, 0)["temperature"] == 72.5
      assert Enum.at(results, 1)["temperature"] == 68.0
      assert Enum.at(results, 2)["temperature"] == 75.2
    end

    test "returns error if any record fails transformation" do
      source_records = [
        %{"temp" => 72.5, "humidity" => 45},
        %{"temp" => 68.0},
        %{"temp" => 75.2, "humidity" => 42}
      ]

      mappings = [
        %{source_field: "temp", target_field: "temperature", required: true},
        %{source_field: "humidity", target_field: "humidity_percent", required: true}
      ]

      assert {:error, reason} = DataMapper.transform(source_records, mappings)
      assert reason =~ "Transformation failed"
      assert reason =~ "humidity"
    end

    test "handles empty record list" do
      mappings = [
        %{source_field: "temp", target_field: "temperature", required: true}
      ]

      assert {:ok, results} = DataMapper.transform([], mappings)
      assert results == []
    end

    test "transforms complex nested data from real API" do
      # Simulating data from a weather API
      source_records = [
        %{
          "location" => %{
            "city" => "Portland",
            "coordinates" => %{"lat" => 45.5, "lon" => -122.6}
          },
          "current" => %{
            "temperature" => 72.5,
            "conditions" => "sunny"
          },
          "timestamp" => "2024-01-31T10:00:00Z"
        }
      ]

      mappings = [
        %{source_field: "location.city", target_field: "city", required: true},
        %{source_field: "location.coordinates.lat", target_field: "latitude", required: true},
        %{source_field: "location.coordinates.lon", target_field: "longitude", required: true},
        %{source_field: "current.temperature", target_field: "temp", required: true},
        %{source_field: "current.conditions", target_field: "weather", required: true},
        %{source_field: "timestamp", target_field: "recorded_at", required: true}
      ]

      assert {:ok, [result]} = DataMapper.transform(source_records, mappings)
      assert result["city"] == "Portland"
      assert result["latitude"] == 45.5
      assert result["longitude"] == -122.6
      assert result["temp"] == 72.5
      assert result["weather"] == "sunny"
      assert result["recorded_at"] == "2024-01-31T10:00:00Z"
    end
  end

  describe "error handling" do
    test "handles invalid input types" do
      assert {:error, reason} = DataMapper.transform("not a list", [])
      assert reason =~ "Invalid input"

      assert {:error, reason} = DataMapper.transform([], "not a list")
      assert reason =~ "Invalid input"
    end

    test "handles malformed mapping" do
      source = %{"temp" => 72.5}

      # Missing source_field
      mappings = [%{target_field: "temperature"}]

      assert {:error, _reason} = DataMapper.transform_record(source, mappings)
    end
  end
end
