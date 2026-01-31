defmodule ElixirTRPC.Introspection do
  import Plug.Conn

  alias ElixirTRPC.JSON

  def init(opts), do: opts

  def call(conn, opts) do
    router = Keyword.fetch!(opts, :router)

    contract_data = fetch_contracts(router)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, JSON.encode!(contract_data))
    |> halt()
  end

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
