defmodule Yuzu do
  @moduledoc """
  TRPC-style RPC endpoints for Elixir with compile-time schema definitions.

  `Yuzu` provides a type-safe, schema-driven approach to building JSON-RPC style
  APIs in Elixir. It uses the [Zoi](https://hex.pm/packages/zoi) library for
  runtime validation and schema definition, giving you:

  - **Compile-time schema definitions** - Define input/output contracts with Zoi schemas
  - **Automatic validation** - Request parameters and responses are validated automatically
  - **Type coercion** - Input values are coerced to the expected types automatically
  - **Introspection** - Generate JSON Schema definitions for all your endpoints
  - **Plug integration** - Works seamlessly with Phoenix and any Plug-based application

  ## Installation

  Add `yuzu` to your list of dependencies in `mix.exs`:

      def deps do
        [
          {:yuzu, "~> 0.1.0"},
          {:jason, "~> 1.4"}  # Optional, but recommended
        ]
      end

  ## Quick Start

  Define an RPC function using `Yuzu.Function`:

      defmodule MyApp.RPC.GetUser do
        use Yuzu.Function,
          params: Zoi.map(%{id: Zoi.string()}),
          result: Zoi.map(%{
            id: Zoi.string(),
            name: Zoi.string(),
            email: Zoi.email()
          })

        @impl true
        def execute(%{id: id}, _context) do
          # Fetch user from database
          {:ok, %{id: id, name: "John Doe", email: "john@example.com"}}
        end
      end

  Mount it in your router:

      defmodule MyAppWeb.Router do
        use Phoenix.Router

        scope "/api" do
          post "/getUser", MyApp.RPC.GetUser, []
        end
      end

  ## Architecture

  `Yuzu` is built on several core components:

  - `Yuzu.Function` - The main macro for defining RPC endpoints with schemas
  - `Yuzu.Conn` - Helpers for JSON response handling
  - `Yuzu.JSON` - Abstraction layer for JSON encoding/decoding
  - `Yuzu.Introspection` - Endpoint for discovering all available RPC contracts

  ## Configuration

  ### JSON Library

  By default, `Yuzu` will use `Jason` if available, falling back to the
  JSON module from Elixir 1.18+. You can also explicitly configure it:

      # In config/config.exs
      config :yuzu, :json_library, Jason

  Or use Phoenix's configured JSON library:

      config :phoenix, :json_library, Jason

  ### Error Handling

  Validation errors are automatically returned in a structured format:

      // Request: POST /api/getUser
      // Body: {"id": 123}  // Wrong type

      // Response: 400 Bad Request
      {
        "errors": {
          "id": ["expected string, got integer"]
        }
      }

  ## Examples

  ### Basic CRUD Operations

      defmodule MyApp.RPC.CreatePost do
        use Yuzu.Function,
          params: Zoi.map(%{
            title: Zoi.string() |> Zoi.min(1) |> Zoi.max(200),
            content: Zoi.string() |> Zoi.min(1),
            published: Zoi.boolean()
          }),
          result: Zoi.map(%{
            id: Zoi.string(),
            title: Zoi.string(),
            created_at: Zoi.string()
          })

        @impl true
        def execute(params, %{current_user: user}) do
          case Posts.create(user, params) do
            {:ok, post} -> {:ok, %{id: post.id, title: post.title, created_at: post.inserted_at}}
            {:error, changeset} -> {:error, changeset}
          end
        end
      end

  ### With Optional Fields

      defmodule MyApp.RPC.UpdateProfile do
        use Yuzu.Function,
          params: Zoi.map(%{
            name: Zoi.string() |> Zoi.optional(),
            bio: Zoi.string() |> Zoi.optional(),
            age: Zoi.integer() |> Zoi.min(0) |> Zoi.optional()
          }),
          result: Zoi.map(%{
            success: Zoi.boolean()
          })

        @impl true
        def execute(params, _context) do
          # params only contains the fields that were provided
          {:ok, %{success: true}}
        end
      end

  ### Nested Objects

      defmodule MyApp.RPC.CreateOrder do
        use Yuzu.Function,
          params: Zoi.map(%{
            customer: Zoi.map(%{
              name: Zoi.string(),
              email: Zoi.email()
            }),
            items: Zoi.list(Zoi.map(%{
              product_id: Zoi.string(),
              quantity: Zoi.integer() |> Zoi.min(1)
            }))
          }),
          result: Zoi.map(%{
            order_id: Zoi.string(),
            total: Zoi.number()
          })

        @impl true
        def execute(params, _context) do
          # Process the order
          {:ok, %{order_id: "ord_123", total: 99.99}}
        end
      end

  ## Introspection

  `Yuzu` can generate a JSON Schema description of all your endpoints for
  client code generation:

      defmodule MyAppWeb.IntrospectionRouter do
        use Plug.Router

        plug Yuzu.Introspection, router: MyAppWeb.Router
      end

  Accessing this endpoint returns all contracts with their JSON Schema definitions.

  ## Why Yuzu?

  - **Type Safety**: Catch errors at the boundary, not in production
  - **Developer Experience**: Clear error messages for API consumers
  - **Client Generation**: JSON Schema enables automatic client generation
  - **Performance**: Compile-time schema validation minimizes runtime overhead
  - **Simplicity**: No code generation or complex build steps required

  See the [GitHub repository](https://github.com/robsonperassoli/yuzu) for
  more examples and advanced usage patterns.
  """
end
