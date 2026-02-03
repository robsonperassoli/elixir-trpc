defmodule Yuzu.Function do
  @moduledoc """
  Macro for defining type-safe RPC endpoints with compile-time schema validation.

  This module provides the `__using__` macro that transforms a module into a
  Plug-compatible RPC endpoint with automatic input validation and output
  verification using Zoi schemas.

  ## Usage

  Define an RPC function by using `Yuzu.Function` with `:params` and
  `:result` options:

      defmodule MyApp.RPC.GetUser do
        use Yuzu.Function,
          params: Zoi.map(%{id: Zoi.string()}),
          result: Zoi.map(%{
            id: Zoi.string(),
            name: Zoi.string(),
            email: Zoi.email()
          })

        @impl true
        def execute(%{id: id}, _context) do
          user = Accounts.get_user!(id)
          {:ok, %{id: user.id, name: user.name, email: user.email}}
        end
      end

  ## Options

  - `:params` - A Zoi schema defining the expected input parameters
  - `:result` - A Zoi schema defining the expected return structure

  Both options are required.

  ## The `execute/2` Callback

  Every RPC function must implement the `c:execute/2` callback:

      @callback execute(params :: map(), context :: map()) :: {:ok, map()} | {:error, any()}

  - `params` - The validated and coerced input parameters
  - `context` - The Plug connection assigns (useful for accessing current_user, etc.)

  ## Plug Integration

  The generated module is a Plug and can be mounted in any Plug-based router:

      # In Phoenix router
      scope "/api", MyAppWeb do
        pipe_through :api

        post "/get_user", RPC.GetUser, []
      end

      # Or with Plug.Router
      post "/get_user", to: MyApp.RPC.GetUser

  ## Request Lifecycle

  1. **Input Validation**: Request params are validated against the `:params` schema
  2. **Type Coercion**: Values are coerced to expected types (e.g., string "123" → integer 123)
  3. **Execution**: `execute/2` is called with validated params and connection context
  4. **Output Validation**: The result is validated against the `:result` schema
  5. **Response**: JSON response is returned with appropriate status codes

  ## Error Handling

  ### Input Validation Errors (400 Bad Request)

  When request parameters fail validation:

      POST /api/get_user
      Body: {"id": 123}

      Response:
      {
        "errors": {
          "id": ["expected string, got integer"]
        }
      }

  ### Output Validation Errors (500 Internal Server Error)

  When the function returns data that doesn't match the result schema:

      {
        "errors": {
          "email": ["expected string, got nil"]
        }
      }

  ### Successful Response (200 OK)

      {
        "id": "user_123",
        "name": "John Doe",
        "email": "john@example.com"
      }

  ## Introspection

  Generated modules expose their contracts for runtime introspection:

      MyApp.RPC.GetUser.__contract__()
      # => %{input: %Zoi.Map{...}, output: %Zoi.Map{...}}

      MyApp.RPC.GetUser.__json_schema__()
      # => %{input: %{type: "object", ...}, output: %{type: "object", ...}}

  ## Schema Reference

  See the [Zoi documentation](https://hexdocs.pm/zoi) for all available
  schema types and validators:

  - `Zoi.string()` / `Zoi.string() |> Zoi.min(1) |> Zoi.max(100)`
  - `Zoi.integer()` / `Zoi.integer() |> Zoi.min(0) |> Zoi.max(100)`
  - `Zoi.number()` / `Zoi.float()`
  - `Zoi.boolean()`
  - `Zoi.email()`
  - `Zoi.uuid()`
  - `Zoi.literal("value")`
  - `Zoi.list(item_schema)` / `Zoi.list(Zoi.string())`
  - `Zoi.map(%{field: schema})`
  - `schema |> Zoi.optional()`
  - `Zoi.union([schema1, schema2])`

  ## Examples

  ### With Optional Fields

      defmodule UpdateProfile do
        use Yuzu.Function,
          params: Zoi.map(%{
            name: Zoi.string() |> Zoi.optional(),
            bio: Zoi.string() |> Zoi.optional()
          }),
          result: Zoi.map(%{success: Zoi.boolean()})

        def execute(params, _context) do
          # params only contains fields that were actually provided
          {:ok, %{success: true}}
        end
      end

  ### With Nested Objects

      defmodule CreateOrder do
        use Yuzu.Function,
          params: Zoi.map(%{
            items: Zoi.list(Zoi.map(%{
              product_id: Zoi.string(),
              quantity: Zoi.integer() |> Zoi.min(1)
            }))
          }),
          result: Zoi.map(%{order_id: Zoi.string()})

        def execute(%{items: items}, _context) do
          order = Orders.create(items)
          {:ok, %{order_id: order.id}}
        end
      end

  ### With Unions

      defmodule Search do
        use Yuzu.Function,
          params: Zoi.map(%{
            query: Zoi.string(),
            filter: Zoi.union([
              Zoi.literal("users"),
              Zoi.literal("posts"),
              Zoi.literal("all")
            ])
          }),
          result: Zoi.map(%{results: Zoi.list(Zoi.map(%{id: Zoi.string()}))})

        def execute(params, _context) do
          {:ok, %{results: Search.search(params)}}
        end
      end
  """

  @doc """
  Callback for executing the RPC endpoint with validated params.

  Implement this callback to define the business logic of your RPC function.

  ## Parameters

  - `params` - A map containing the validated and coerced input parameters
  - `context` - A map containing the Plug connection assigns (e.g., `%{current_user: user}`)

  ## Return Value

  Must return `{:ok, map()}` on success, where the map matches the `:result`
  schema defined in `use Yuzu.Function`.

  May return `{:error, any()}` on failure. Note that error responses are not
  currently validated against a schema - the error is passed through as-is.

  ## Examples

      @impl true
      def execute(%{id: id}, %{current_user: user}) do
        case Accounts.get_user(id) do
          nil -> {:error, :not_found}
          user -> {:ok, %{id: user.id, name: user.name}}
        end
      end
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
          raise ArgumentError, ":params option is required when using Yuzu.Function"
      end

    result_schema =
      case Keyword.fetch(opts, :result) do
        {:ok, ast} ->
          {value, _binding} = Code.eval_quoted(ast, [], caller)
          value

        :error ->
          raise ArgumentError, ":result option is required when using Yuzu.Function"
      end

    quote do
      @behaviour Plug
      @behaviour Yuzu.Function
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
                    Yuzu.Conn.json_response(conn, validated_result)

                  {:error, [%Zoi.Error{} | _] = errors} ->
                    conn
                    |> put_status(:internal_server_error)
                    |> Yuzu.Conn.json_response(%{errors: Zoi.treefy_errors(errors)})
                end
            end

          {:error, [%Zoi.Error{} | _] = errors} ->
            conn
            |> put_status(:bad_request)
            |> Yuzu.Conn.json_response(%{errors: Zoi.treefy_errors(errors)})
        end
      end

      @doc """
      Returns the contract definition with compile-time schemas.

      This function returns the raw Zoi schemas for input and output,
      useful for runtime introspection and code generation.

      ## Example

          MyApp.RPC.GetUser.__contract__()
          # => %{
          #   input: %Zoi.Map{...},
          #   output: %Zoi.Map{...}
          # }
      """
      def __contract__ do
        %{
          input: unquote(Macro.escape(params_schema)),
          output: unquote(Macro.escape(result_schema))
        }
      end

      @doc """
      Returns the JSON Schema representation of the contracts.

      This function converts the Zoi schemas to JSON Schema format,
      enabling automatic client code generation and API documentation.

      ## Example

          MyApp.RPC.GetUser.__json_schema__()
          # => %{
          #   input: %{type: "object", properties: %{id: %{type: "string"}}},
          #   output: %{type: "object", properties: %{...}}
          # }
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
