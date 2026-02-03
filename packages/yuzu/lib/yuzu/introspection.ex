defmodule Yuzu.Introspection do
  @moduledoc """
  Plug for exposing JSON Schema definitions of all RPC endpoints.

  This module provides introspection capabilities for your Yuzu API, allowing
  clients to discover available endpoints and their input/output schemas at runtime.
  This enables automatic client code generation and API documentation.

  ## Usage

  Mount the introspection plug in your router, providing the router module
  that contains your RPC endpoints:

      defmodule MyAppWeb.Router do
        use Phoenix.Router

        # Your RPC endpoints
        scope "/api" do
          post "/getUser", MyApp.RPC.GetUser, []
          post "/createPost", MyApp.RPC.CreatePost, []
        end
      end

      # Introspection endpoint
      defmodule MyAppWeb.IntrospectionRouter do
        use Plug.Router

        plug Yuzu.Introspection, router: MyAppWeb.Router
      end

  ## Response Format

  The introspection endpoint returns a JSON array of all discovered RPC contracts:

      [
        {
          "name": "GetUser",
          "path": "/api/getUser",
          "verb": "POST",
          "input": {
            "type": "object",
            "properties": {
              "id": {"type": "string"}
            },
            "required": ["id"]
          },
          "output": {
            "type": "object",
            "properties": {
              "id": {"type": "string"},
              "name": {"type": "string"},
              "email": {"type": "string", "format": "email"}
            },
            "required": ["id", "name", "email"]
          }
        }
      ]

  ## Endpoint Naming

  The endpoint name is derived from the module name. For a module like
  `MyAppWeb.RPC.GetUser`, the name becomes `"GetUser"` (the last part
  after splitting by dots).

  ## Security Considerations

  > **Warning**: Introspection exposes your entire API schema. In production,
  > you should protect this endpoint with authentication:

      # In Phoenix
      scope "/api" do
        pipe_through [:api, :admin]  # Add admin authentication
        get "/introspect", Yuzu.Introspection, router: MyAppWeb.Router
      end

  ## Configuration Options

  - `:router` (required) - The router module containing the RPC endpoints to introspect

  ## Examples

  ### Basic Setup

      # router.ex
      defmodule MyAppWeb.Router do
        use Phoenix.Router

        scope "/api" do
          post "/users", MyApp.RPC.ListUsers, []
          post "/users/create", MyApp.RPC.CreateUser, []
        end
      end

      # introspection.ex
      defmodule MyAppWeb.IntrospectionController do
        use Plug.Builder

        plug Yuzu.Introspection, router: MyAppWeb.Router
      end

  ### With Authentication

      # In your router
      scope "/admin" do
        pipe_through :admin_auth

        get "/schema", Yuzu.Introspection, router: MyAppWeb.Router
      end

  ### Client Code Generation

  The introspection output can be used with tools like:
  - [OpenAPI Generator](https://openapi-generator.tech/)
  - [QuickType](https://app.quicktype.io/)
  - Custom client generators

  Example client generation workflow:

      # Fetch schema from your API
      curl https://api.example.com/admin/schema > schema.json

      # Generate TypeScript client
      quicktype -s schema -o api-client.ts schema.json
  """

  import Plug.Conn

  alias Yuzu.JSON

  @doc """
  Initializes the plug with options.

  ## Options

  - `:router` - Required. The router module to introspect for RPC endpoints.

  ## Returns

  The validated options.
  """
  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @doc """
  Handles the introspection request.

  Fetches all RPC contracts from the configured router and returns them
  as a JSON response.
  """
  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, opts) do
    router = Keyword.fetch!(opts, :router)

    contract_data = fetch_contracts(router)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, JSON.encode!(contract_data))
    |> halt()
  end

  # Fetches contracts from all TRPC functions in the router
  @spec fetch_contracts(module()) :: list(map())
  defp fetch_contracts(router) do
    router.__routes__()
    |> Enum.filter(fn route ->
      Code.ensure_loaded?(route.plug) &&
        function_exported?(route.plug, :__json_schema__, 0)
    end)
    |> Enum.map(fn route ->
      json_schema = route.plug.__json_schema__()

      # Considering that `MyAppWeb.RPC` should be removed
      [_, _ | name_parts] = Module.split(route.plug)

      %{
        name: Enum.join(name_parts, ""),
        path: route.path,
        verb: route.verb,
        input: json_schema.input,
        output: json_schema.output
      }
    end)
  end
end
