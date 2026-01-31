defmodule ElixirTRPC do
  @callback params_schema() :: Zoi.Type.t()
  @callback result_schema() :: Zoi.Type.t()
  @callback execute(map(), map()) :: {:ok, map()} | {:error, any()}

  defmacro __using__(_opts) do
    quote do
      @behaviour ElixirTRPC
      @behaviour Plug

      import Plug.Conn

      # Standard Plug init
      @impl true
      def init(opts), do: opts

      # The actual entry point from Phoenix Router
      @impl true
      def call(conn, _opts) do
        params = conn.params
        params_schema = params_schema()

        case Zoi.parse(params_schema, params, coerce: true) do
          {:ok, validated_params} ->
            # Execute the business logic
            case execute(validated_params, conn.assigns) do
              {:ok, result} ->
                # Validate output before sending to ensure contract isn't broken
                case Zoi.parse(result_schema(), result) do
                  {:ok, validated_result} ->
                    ElixirTRPC.Conn.json_response(conn, validated_result)

                  {:error, [%Zoi.Error{} | _] = errors} ->
                    conn
                    |> put_status(:internal_server_error)
                    |> ElixirTRPC.Conn.json_response(%{errors: Zoi.treefy_errors(errors)})
                end
            end

          {:error, [%Zoi.Error{} | _] = errors} ->
            conn
            |> put_status(:bad_request)
            |> ElixirTRPC.Conn.json_response(%{errors: Zoi.treefy_errors(errors)})
        end
      end

      def __contract__ do
        %{
          input: params_schema(),
          output: result_schema()
        }
      end
    end
  end
end
