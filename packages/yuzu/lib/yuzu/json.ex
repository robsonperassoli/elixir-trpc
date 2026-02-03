defmodule Yuzu.JSON do
  @moduledoc """
  JSON encoding and decoding abstraction for Yuzu.

  This module provides a thin abstraction layer over JSON libraries, allowing
  `Yuzu` to work with different JSON implementations without hard
  dependencies.

  ## Library Selection

  The JSON library is resolved in the following priority order:

  1. Application config: `config :yuzu, :json_library, Jason`
  2. Phoenix config: `config :phoenix, :json_library, Jason`
  3. Auto-detection: `Jason` if available, otherwise `JSON` (Elixir 1.18+)

  ## Configuration

  Explicitly configure the JSON library in your `config/config.exs`:

      config :yuzu, :json_library, Jason

  Or use Phoenix's configuration:

      config :phoenix, :json_library, Jason

  ## Supported Libraries

  - [Jason](https://hex.pm/packages/jason) - Recommended, fast and feature-rich
  - [JSON](https://hexdocs.pm/elixir/JSON.html) - Built into Elixir 1.18+
  - Any module implementing `encode/1`, `encode!/1`, `decode/1`, `decode!/1`

  ## Examples

      # Encoding
      Yuzu.JSON.encode!(%{user: "john"})
      # => ~s|{"user":"john"}|

      # Decoding
      Yuzu.JSON.decode!(~s|{"user":"john"}|)
      # => %{"user" => "john"}

  """

  @doc """
  Encodes a term to JSON, raising on error.

  ## Parameters

  - `data` - The Elixir term to encode (map, list, string, etc.)

  ## Returns

  A JSON string.

  ## Raises

  - Raises if encoding fails (e.g., for non-encodable terms).

  ## Examples

      iex> Yuzu.JSON.encode!(%{name: "John"})
      ~s|{"name":"John"}|

  """
  @spec encode!(term()) :: String.t()
  def encode!(data) do
    json_library().encode!(data)
  end

  @doc """
  Encodes a term to JSON, returning a result tuple.

  ## Parameters

  - `data` - The Elixir term to encode

  ## Returns

  - `{:ok, json_string}` on success
  - `{:error, reason}` on failure

  ## Examples

      iex> Yuzu.JSON.encode(%{name: "John"})
      {:ok, ~s|{"name":"John"}|}

      iex> Yuzu.JSON.encode(self())
      {:error, %Protocol.UndefinedError{}}

  """
  @spec encode(term()) :: {:ok, String.t()} | {:error, term()}
  def encode(data) do
    json_library().encode(data)
  end

  @doc """
  Decodes a JSON string, raising on error.

  ## Parameters

  - `data` - The JSON string to decode

  ## Returns

  The decoded Elixir term (maps, lists, strings, numbers, booleans, nil).

  ## Raises

  - Raises `Jason.DecodeError` or equivalent if JSON is invalid.

  ## Examples

      iex> Yuzu.JSON.decode!(~s|{"name":"John"}|)
      %{"name" => "John"}

  """
  @spec decode!(String.t()) :: term()
  def decode!(data) do
    json_library().decode!(data)
  end

  @doc """
  Decodes a JSON string, returning a result tuple.

  ## Parameters

  - `data` - The JSON string to decode

  ## Returns

  - `{:ok, term}` on success
  - `{:error, reason}` on failure

  ## Examples

      iex> Yuzu.JSON.decode(~s|{"name":"John"}|)
      {:ok, %{"name" => "John"}}

      iex> Yuzu.JSON.decode("invalid json")
      {:error, %Jason.DecodeError{}}

  """
  @spec decode(String.t()) :: {:ok, term()} | {:error, term()}
  def decode(data) do
    json_library().decode(data)
  end

  # Resolves the configured JSON library
  @spec json_library() :: module()
  defp json_library do
    Application.get_env(:yuzu, :json_library) ||
      Application.get_env(:phoenix, :json_library) ||
      default_library()
  end

  # Auto-detects a default JSON library
  @spec default_library() :: module()
  defp default_library do
    cond do
      Code.ensure_loaded?(Jason) ->
        Jason

      Code.ensure_loaded?(JSON) ->
        JSON

      true ->
        raise "No JSON encoder found. Please add :jason to your deps or configure :json_library."
    end
  end
end
