defmodule ElixirTrpcTest do
  use ExUnit.Case, async: true
  use Plug.Test

  doctest ElixirTrpc

  test "greets the world" do
    assert ElixirTrpc.hello() == :world
  end
end
