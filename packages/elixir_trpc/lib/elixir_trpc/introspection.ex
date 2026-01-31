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
        function_exported?(route.plug, :__contract__, 0)
    end)
    |> Enum.map(fn route ->
      contract = route.plug.__contract__()

      # Considering that `MyAppWeb.RPC` should be removed
      [_, _ | name_parts] = Module.split(route.plug)

      %{
        name: Enum.join(name_parts, ""),
        path: route.path,
        verb: route.verb,
        input: Zoi.to_json_schema(contract.input),
        output: Zoi.to_json_schema(contract.output)
      }
    end)
  end
end
