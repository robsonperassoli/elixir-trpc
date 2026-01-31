defmodule ElixirTRPC.Conn do
  import Plug.Conn

  alias ElixirTRPC.JSON

  def json_response(conn, data) do
    json = JSON.encode!(data)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(conn.status || 200, json)
  end
end
