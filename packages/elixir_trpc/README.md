# ElixirTRPC

[![Hex Version](https://img.shields.io/hexpm/v/elixir_trpc.svg)](https://hex.pm/packages/elixir_trpc)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/elixir_trpc)
[![License](https://img.shields.io/hexpm/l/elixir_trpc.svg)](https://github.com/robsonperassoli/elixir_trpc/blob/main/LICENSE)

Type-safe, schema-driven JSON-RPC endpoints for Elixir with compile-time validation.

ElixirTRPC brings [tRPC](https://trpc.io/)-style development to the Elixir ecosystem, combining the power of Elixir's concurrency with Zoi's runtime validation to create robust, self-documenting APIs.

## Features

- 🎯 **Compile-time Schema Validation** - Define input/output contracts with Zoi schemas
- 🔄 **Automatic Type Coercion** - Input values are intelligently converted to expected types
- 🔍 **Introspection** - Generate JSON Schema definitions for client code generation
- ⚡ **Plug Integration** - Works seamlessly with Phoenix and any Plug-based application
- 🛡️ **Type Safety** - Catch API contract violations before they reach production
- 📝 **Clear Error Messages** - Helpful validation errors for API consumers

## Installation

Add `elixir_trpc` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:elixir_trpc, "~> 0.1.0"},
    {:jason, "~> 1.4"}  # Optional but recommended
  ]
end
```

## Quick Start

### 1. Define an RPC Function

Create a module using `ElixirTRPC.Function` with `params` and `result` schemas:

```elixir
defmodule MyApp.RPC.GetUser do
  use ElixirTRPC.Function,
    params: Zoi.map(%{id: Zoi.string()}),
    result: Zoi.map(%{
      id: Zoi.string(),
      name: Zoi.string(),
      email: Zoi.email()
    })

  @impl true
  def execute(%{id: id}, _context) do
    user = Accounts.get_user!(id)
    {:ok, %{id: user.id, name: user.name, email: user.email}}
  end
end
```

### 2. Mount in Your Router

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router

  scope "/api" do
    pipe_through :api

    post "/get_user", MyApp.RPC.GetUser, []
  end
end
```

### 3. Make Requests

```bash
curl -X POST http://localhost:4000/api/get_user \
  -H "Content-Type: application/json" \
  -d '{"id": "user_123"}'

# Response: {"id":"user_123","name":"John Doe","email":"john@example.com"}
```

## Usage Guide

### Defining Schemas

ElixirTRPC uses [Zoi](https://hex.pm/packages/zoi) for schema definition. Here are common patterns:

```elixir
# Basic types
Zoi.string()
Zoi.integer()
Zoi.number()
Zoi.boolean()

# With constraints
Zoi.string() |> Zoi.min(1) |> Zoi.max(100)
Zoi.integer() |> Zoi.min(0) |> Zoi.max(120)
Zoi.email()
Zoi.uuid()

# Optional fields
Zoi.string() |> Zoi.optional()

# Lists
Zoi.list(Zoi.string())
Zoi.list(Zoi.map(%{id: Zoi.string()}))

# Nested objects
Zoi.map(%{
  user: Zoi.map(%{
    name: Zoi.string(),
    age: Zoi.integer()
  })
})

# Unions (one of several types)
Zoi.union([Zoi.string(), Zoi.integer()])
Zoi.union([
  Zoi.literal("active"),
  Zoi.literal("inactive"),
  Zoi.literal("pending")
])
```

### Accessing Context

The `execute/2` callback receives connection assigns as the second argument:

```elixir
defmodule MyApp.RPC.CreatePost do
  use ElixirTRPC.Function,
    params: Zoi.map(%{
      title: Zoi.string(),
      content: Zoi.string()
    }),
    result: Zoi.map(%{id: Zoi.string()})

  @impl true
  def execute(params, %{current_user: user}) do
    case Blog.create_post(user, params) do
      {:ok, post} -> {:ok, %{id: post.id}}
      {:error, changeset} -> {:error, changeset}
    end
  end
end
```

Configure your pipeline to set `current_user`:

```elixir
pipeline :api do
  plug :accepts, ["json"]
  plug MyAppWeb.Plugs.Authenticate
end
```

### Error Handling

Validation errors are automatically returned with descriptive messages:

**Input Validation Error (400 Bad Request):**
```json
{
  "errors": {
    "email": ["expected string to be a valid email"],
    "age": ["expected integer to be >= 18"]
  }
}
```

**Output Validation Error (500 Internal Server Error):**
```json
{
  "errors": {
    "name": ["expected string, got nil"]
  }
}
```

## Introspection

Generate JSON Schema definitions for all your endpoints to enable client code generation:

```elixir
# In your router
scope "/admin" do
  pipe_through [:api, :admin_auth]

  get "/schema", ElixirTRPC.Introspection, router: MyAppWeb.Router
end
```

Response format:
```json
[
  {
    "name": "GetUser",
    "path": "/api/get_user",
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
      }
    }
  }
]
```

## Configuration

### JSON Library

ElixirTRPC auto-detects your JSON library (prefers Jason, falls back to Elixir's built-in JSON). To explicitly configure:

```elixir
# config/config.exs
config :elixir_trpc, :json_library, Jason
```

## Examples

### CRUD Operations

```elixir
defmodule MyApp.RPC.ListPosts do
  use ElixirTRPC.Function,
    params: Zoi.map(%{
      page: Zoi.integer() |> Zoi.min(1) |> Zoi.optional(),
      per_page: Zoi.integer() |> Zoi.min(1) |> Zoi.max(100) |> Zoi.optional()
    }),
    result: Zoi.map(%{
      posts: Zoi.list(Zoi.map(%{
        id: Zoi.string(),
        title: Zoi.string()
      })),
      total: Zoi.integer()
    })

  @impl true
  def execute(params, _context) do
    page = Map.get(params, :page, 1)
    per_page = Map.get(params, :per_page, 20)
    
    {posts, total} = Blog.list_posts(page: page, per_page: per_page)
    
    {:ok, %{
      posts: Enum.map(posts, &%{id: &1.id, title: &1.title}),
      total: total
    }}
  end
end
```

### Nested Validation

```elixir
defmodule MyApp.RPC.CreateOrder do
  use ElixirTRPC.Function,
    params: Zoi.map(%{
      customer: Zoi.map(%{
        name: Zoi.string(),
        email: Zoi.email()
      }),
      items: Zoi.list(Zoi.map(%{
        product_id: Zoi.string(),
        quantity: Zoi.integer() |> Zoi.min(1),
        price: Zoi.number()
      })) |> Zoi.min(1)
    }),
    result: Zoi.map(%{
      order_id: Zoi.string(),
      total: Zoi.number()
    })

  @impl true
  def execute(%{customer: customer, items: items}, _context) do
    total = Enum.reduce(items, 0, fn item, acc -> 
      acc + item.quantity * item.price 
    end)
    
    order = Orders.create(customer, items)
    
    {:ok, %{order_id: order.id, total: total}}
  end
end
```

## Why ElixirTRPC?

- **Type Safety at the Boundary**: Validate once, trust everywhere
- **Self-Documenting**: Schemas serve as living API documentation
- **Client Generation**: JSON Schema enables automatic TypeScript/Go/Rust clients
- **No Build Steps**: Pure Elixir with macro-powered compile-time validation
- **Production Ready**: Battle-tested validation with Zoi

## Documentation

Full documentation is available at [https://hexdocs.pm/elixir_trpc](https://hexdocs.pm/elixir_trpc).

## License

MIT License - see [LICENSE](./LICENSE) for details.