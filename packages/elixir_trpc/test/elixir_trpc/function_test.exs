defmodule ElixirTRPC.FunctionTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias ElixirTRPC.JSON

  doctest ElixirTRPC.Function

  defmodule GetProfile do
    use ElixirTRPC.Function,
      params: Zoi.map(%{id: Zoi.string()}),
      result:
        Zoi.map(%{
          name: Zoi.string() |> Zoi.min(2) |> Zoi.max(100),
          age: Zoi.integer() |> Zoi.min(18) |> Zoi.max(120),
          email: Zoi.email()
        })

    @impl true
    def execute(%{id: id}, _context) do
      case id do
        "error" -> {:ok, %{url: "test"}}
        _id -> {:ok, %{name: "Johhny Bravo", age: 30, email: "jonny@example.com"}}
      end
    end
  end

  test "get profile works with parameters" do
    conn =
      conn(:get, "/profile", %{"id" => "123"})
      |> GetProfile.call(%{})

    assert JSON.decode!(conn.resp_body) == %{
             "name" => "Johhny Bravo",
             "age" => 30,
             "email" => "jonny@example.com"
           }

    assert conn.status == 200
  end

  test "fails with 400 when params dont match the types" do
    conn =
      conn(:get, "/profile", %{"invalid" => "123"})
      |> GetProfile.call(%{})

    assert JSON.decode!(conn.resp_body) == %{"errors" => %{"id" => ["is required"]}}
    assert conn.status == 400
  end

  test "fails with 500 when result doesnt match the types" do
    conn =
      conn(:get, "/profile", %{"id" => "error"})
      |> GetProfile.call(%{})

    assert JSON.decode!(conn.resp_body) == %{
             "errors" => %{
               "age" => ["is required"],
               "email" => ["is required"],
               "name" => ["is required"]
             }
           }

    assert conn.status == 500
  end
end
