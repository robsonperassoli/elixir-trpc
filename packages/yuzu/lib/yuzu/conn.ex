defmodule Yuzu.Conn do
  @moduledoc """
  HTTP connection helpers for JSON response handling.

  This module provides utility functions for working with Plug connections
  and returning JSON responses in Yuzu endpoints.

  ## Usage

  Typically, you won't need to use this module directly as `Yuzu.Function`
  handles response generation automatically. However, it can be useful for
  custom middleware or when building custom RPC implementations.

  ## Examples

      defmodule MyCustomMiddleware do
        import Plug.Conn

        def call(conn, opts) do
          # Do something with the connection
          conn = assign(conn, :custom_data, "value")

          # Return a JSON response
          Yuzu.Conn.json_response(conn, %{success: true})
        end
      end

  """

  import Plug.Conn

  alias Yuzu.JSON

  @doc """
  Sends a JSON response with the given data.

  Encodes the data as JSON, sets the content type to `application/json`,
  and sends the response with the current connection status (defaults to 200).

  ## Parameters

  - `conn` - The Plug connection struct
  - `data` - The Elixir term to encode as JSON

  ## Returns

  The connection struct with the response sent.

  ## Examples

      # In a Plug endpoint
      def call(conn, _opts) do
        data = %{message: "Hello, World!"}
        json_response(conn, data)
      end

      # With custom status
      conn
      |> put_status(:created)
      |> json_response(%{id: "new_123"})

  """
  @spec json_response(Plug.Conn.t(), term()) :: Plug.Conn.t()
  def json_response(conn, data) do
    json = JSON.encode!(data)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(conn.status || 200, json)
  end
end
