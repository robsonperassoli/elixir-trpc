defmodule ElixirTRPC.JSON do
  def encode!(data) do
    json_library().encode!(data)
  end

  def encode(data) do
    json_library().encode(data)
  end

  def decode!(data) do
    json_library().decode!(data)
  end

  def decode(data) do
    json_library().decode(data)
  end

  defp json_library do
    Application.get_env(:elixir_trpc, :json_library) ||
      Application.get_env(:phoenix, :json_library) ||
      default_library()
  end

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
