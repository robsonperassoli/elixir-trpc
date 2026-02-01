defmodule ElixirTRPC do
  @moduledoc """
  TRPC-style RPC endpoints for Elixir with compile-time schema definitions.

  ## Example

      defmodule GetProfile do
        use ElixirTRPC.Function,
          params: Zoi.map(%{id: Zoi.string()}),
          result: Zoi.map(%{
            name: Zoi.string() |> Zoi.min(2) |> Zoi.max(100),
            age: Zoi.integer() |> Zoi.min(18) |> Zoi.max(120),
            email: Zoi.email()
          })

        @impl true
        def execute(%{id: id}, _context) do
          {:ok, %{name: "John Doe", age: 30, email: "john@example.com"}}
        end
      end
  """
end
