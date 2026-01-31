defmodule ElixirTRPC.IntrospectionTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias ElixirTRPC.Introspection
  alias ElixirTRPC.JSON

  defmodule GetUser do
    use ElixirTRPC

    @impl true
    def params_schema, do: Zoi.map(%{id: Zoi.string()})

    @impl true
    def result_schema, do: Zoi.map(%{name: Zoi.string()})

    @impl true
    def execute(_params, _context) do
      {:ok, %{name: "Johhny Bravo"}}
    end
  end

  defmodule MockRouter do
    def __routes__() do
      [
        %{plug: GetUser, path: "/users/:id", verb: :get}
      ]
    end
  end

  test "aa" do
    conn = conn(:get, "/introspection", %{})

    conn = Introspection.call(conn, router: MockRouter)
    data = JSON.decode!(conn.resp_body)

    assert [
             %{
               "input" => %{
                 "$schema" => "https://json-schema.org/draft/2020-12/schema",
                 "additionalProperties" => true,
                 "properties" => %{"id" => %{"type" => "string"}},
                 "required" => ["id"],
                 "type" => "object"
               },
               "name" => "GetUser",
               "output" => %{
                 "$schema" => "https://json-schema.org/draft/2020-12/schema",
                 "additionalProperties" => true,
                 "properties" => %{"name" => %{"type" => "string"}},
                 "required" => ["name"],
                 "type" => "object"
               },
               "path" => "/users/:id",
               "verb" => "get"
             }
           ] = data
  end
end
