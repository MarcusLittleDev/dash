defmodule Dash.Adapters.External.HttpTest do
  use ExUnit.Case, async: true

  alias Dash.Adapters.External.Http

  describe "validate_config/1" do
    test "validates required url" do
      assert {:error, "url is required"} = Http.validate_config(%{})
    end

    test "validates url is non-empty string" do
      assert {:error, "url must be a non-empty string"} = Http.validate_config(%{"url" => ""})
    end

    test "validates method is GET or POST" do
      assert {:error, "method must be GET or POST"} =
               Http.validate_config(%{"url" => "https://example.com", "method" => "DELETE"})
    end

    test "validates headers is a map" do
      assert {:error, "headers must be a map"} =
               Http.validate_config(%{"url" => "https://example.com", "headers" => "invalid"})
    end

    test "validates timeout is integer" do
      assert {:error, "timeout must be an integer"} =
               Http.validate_config(%{"url" => "https://example.com", "timeout" => "5000"})
    end

    test "accepts valid minimal config" do
      assert :ok = Http.validate_config(%{"url" => "https://example.com"})
    end

    test "accepts valid full config" do
      config = %{
        "url" => "https://example.com",
        "method" => "POST",
        "headers" => %{"Authorization" => "Bearer token"},
        "timeout" => 5000,
        "body" => %{"key" => "value"}
      }

      assert :ok = Http.validate_config(config)
    end
  end

  describe "fetch/1 with real public APIs" do
    @tag :external_api
    test "fetches list of posts from JSONPlaceholder" do
      config = %{
        "url" => "https://jsonplaceholder.typicode.com/posts"
      }

      assert {:ok, data, metadata} = Http.fetch(config)

      assert is_list(data)
      assert length(data) > 0

      first_post = hd(data)
      assert is_map(first_post)
      assert Map.has_key?(first_post, "userId")
      assert Map.has_key?(first_post, "id")
      assert Map.has_key?(first_post, "title")
      assert Map.has_key?(first_post, "body")

      assert metadata.status_code == 200
    end

    @tag :external_api
    test "fetches single resource and wraps in list" do
      config = %{
        "url" => "https://jsonplaceholder.typicode.com/posts/1"
      }

      assert {:ok, data, metadata} = Http.fetch(config)

      assert is_list(data)
      assert length(data) == 1

      post = hd(data)
      assert post["id"] == 1
      assert is_binary(post["title"])

      assert metadata.status_code == 200
    end

    @tag :external_api
    test "handles custom headers" do
      config = %{
        "url" => "https://jsonplaceholder.typicode.com/posts",
        "headers" => %{
          "Accept" => "application/json",
          "User-Agent" => "Dash-Pipeline-Test"
        }
      }

      assert {:ok, data, metadata} = Http.fetch(config)

      assert is_list(data)
      assert length(data) > 0
      assert metadata.status_code == 200
    end

    @tag :external_api
    test "handles POST requests" do
      config = %{
        "url" => "https://jsonplaceholder.typicode.com/posts",
        "method" => "POST",
        "headers" => %{"Content-Type" => "application/json"},
        "body" => %{
          "title" => "Test Post",
          "body" => "This is a test",
          "userId" => 1
        }
      }

      assert {:ok, data, metadata} = Http.fetch(config)

      assert is_list(data)
      assert length(data) == 1

      created_post = hd(data)
      assert created_post["title"] == "Test Post"
      assert created_post["body"] == "This is a test"
      assert created_post["userId"] == 1
      assert is_integer(created_post["id"])

      assert metadata.status_code == 201
    end
  end

  describe "authentication patterns" do
    test "validates Bearer token authentication config" do
      config = %{
        "url" => "https://api.example.com/data",
        "headers" => %{
          "Authorization" => "Bearer sk_test_1234567890"
        }
      }

      assert :ok = Http.validate_config(config)
    end

    test "validates API key authentication config" do
      config = %{
        "url" => "https://api.example.com/data",
        "headers" => %{
          "X-API-Key" => "your-api-key-here"
        }
      }

      assert :ok = Http.validate_config(config)
    end

    test "validates Basic authentication config" do
      credentials = Base.encode64("username:password")

      config = %{
        "url" => "https://api.example.com/data",
        "headers" => %{
          "Authorization" => "Basic #{credentials}"
        }
      }

      assert :ok = Http.validate_config(config)
    end

    test "validates multiple custom headers for authentication" do
      config = %{
        "url" => "https://api.example.com/data",
        "headers" => %{
          "X-API-Key" => "key123",
          "X-API-Secret" => "secret456",
          "X-Client-ID" => "client789"
        }
      }

      assert :ok = Http.validate_config(config)
    end
  end

  describe "fetch/1 error handling" do
    @tag :external_api
    test "handles 404 not found" do
      config = %{
        "url" => "https://jsonplaceholder.typicode.com/posts/999999999"
      }

      assert {:error, reason} = Http.fetch(config)
      assert reason =~ "HTTP 404"
    end

    test "handles invalid URL" do
      config = %{
        "url" => "not-a-valid-url"
      }

      assert {:error, reason} = Http.fetch(config)
      assert is_binary(reason)
    end

    test "handles timeout" do
      config = %{
        "url" => "https://httpbin.org/delay/10",
        "timeout" => 100
      }

      assert {:error, reason} = Http.fetch(config)
      assert is_binary(reason)
    end
  end
end
