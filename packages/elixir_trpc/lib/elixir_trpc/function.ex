defmodule ElixirTRPC.Function do
  @doc """
  Callback for executing the RPC endpoint with validated params.
  """
  @callback execute(params :: map(), context :: map()) :: {:ok, map()} | {:error, any()}

  @doc false
  defmacro __using__(opts) do
    # Evaluate the options in the caller's context to get the actual schema values
    caller = __CALLER__

    params_schema =
      case Keyword.fetch(opts, :params) do
        {:ok, ast} ->
          {value, _binding} = Code.eval_quoted(ast, [], caller)
          value

        :error ->
          raise ArgumentError, ":params option is required when using ElixirTRPC.Function"
      end

    result_schema =
      case Keyword.fetch(opts, :result) do
        {:ok, ast} ->
          {value, _binding} = Code.eval_quoted(ast, [], caller)
          value

        :error ->
          raise ArgumentError, ":result option is required when using ElixirTRPC.Function"
      end

    quote do
      @behaviour Plug
      @behaviour ElixirTRPC.Function
      import Plug.Conn

      @impl true
      def init(opts), do: opts

      @impl true
      def call(conn, _opts) do
        params = conn.params
        params_schema = unquote(Macro.escape(params_schema))
        result_schema = unquote(Macro.escape(result_schema))

        case Zoi.parse(params_schema, params, coerce: true) do
          {:ok, validated_params} ->
            case execute(validated_params, conn.assigns) do
              {:ok, result} ->
                case Zoi.parse(result_schema, result) do
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

      @doc """
      Returns the contract definition with compile-time schemas.
      """
      def __contract__ do
        %{
          input: unquote(Macro.escape(params_schema)),
          output: unquote(Macro.escape(result_schema))
        }
      end

      @doc """
      Returns the JSON Schema representation of the contracts.
      """
      def __json_schema__ do
        %{
          input: Zoi.to_json_schema(unquote(Macro.escape(params_schema))),
          output: Zoi.to_json_schema(unquote(Macro.escape(result_schema)))
        }
      end
    end
  end
end
