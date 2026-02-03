# Yuzu Codegen

A TypeScript API client generator similar to graphql-codegen. Generates fully-typed, functional-style fetch-based API clients with Zod validation from an introspection JSON endpoint for the Elixir Yuzu framework.

## Features

- ✅ **Functional Style** - No classes, just pure functions
- ✅ **Zod Validation** - Runtime validation of both requests and responses
- ✅ **Fully Typed** - Complete TypeScript types inferred from Zod schemas
- ✅ **Configurable** - Simple config file like graphql-codegen
- ✅ **Watch Mode** - Auto-regenerate when API changes
- ✅ **Path Params** - Automatic URL construction with path parameters
- ✅ **JSON Schema Support** - Full support for JSON Schema types

## Installation

```bash
bun install
```

## Usage

### 1. Create a Config File

Create a `yuzu-codegen.config.ts` file in your project root:

```typescript
import type { YuzuCodegenConfig } from "./src/config.ts";

export default {
  // URL to your API's introspection endpoint
  introspectionUrl: "http://localhost:4000/api/inspect/yuzu",

  // Base URL for API calls (optional, defaults to introspection URL origin)
  baseUrl: "http://localhost:4000",

  // Directory where the generated file will be saved
  outputDir: "./src/gen",

  // Name of the generated file
  outputFile: "yuzu-client.ts",
} satisfies YuzuCodegenConfig;
```

### 2. Generate the API Client

```bash
# Generate once
bun run generate

# Or with watch mode (regenerates when the API changes)
bun run watch

# Or using the CLI directly
bun run ./bin/yuzu-codegen.ts
bun run ./bin/yuzu-codegen.ts --watch
bun run ./bin/yuzu-codegen.ts --config ./my-config.ts
```

### 3. Use the Generated Client

```typescript
import { configure, getProfile, updateProfile } from "./src/gen/yuzu-client.ts";

// Configure the client (optional - uses defaults from config)
configure({
  baseUrl: "http://localhost:4000",
  headers: { Authorization: "Bearer token" },
  // Or use a function for dynamic headers:
  // headers: () => ({ Authorization: `Bearer ${getToken()}` })
});

// Make type-safe API calls with Zod validation
const profile = await getProfile({ id: "user-123" });
// Type: GetProfileResult = { name: string, email: string, age: number }

const updated = await updateProfile({ id: "user-123", name: "John Doe" });
// Type: UpdateProfileResult = { id: string, name: string }
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `introspectionUrl` | `string` | `http://localhost:4000/api/inspect/yuzu` | URL to fetch the introspection JSON |
| `baseUrl` | `string` | Same as introspectionUrl origin | Base URL for API calls |
| `outputDir` | `string` | `./src/gen` | Directory for the generated file |
| `outputFile` | `string` | `yuzu-client.ts` | Name of the generated file |
| `introspectionFile` | `string` | - | Use a local JSON file instead of fetching |
| `headers` | `Record<string, string>` | - | Additional headers for the introspection request |

## CLI Options

```bash
yuzu-codegen [options]

Options:
  -c, --config <path>   Path to config file (yuzu-codegen.config.ts|js|json)
  -w, --watch          Watch mode - regenerate on changes
  -h, --help           Show help message
```

## Introspection Format

The introspection endpoint should return a JSON array of route definitions:

```typescript
Array<{
  name: string;        // Function name, e.g., "GetProfile", "UpdateUser"
  path: string;        // API path, e.g., "/api/users/:id"
  verb: string;        // HTTP method: "get", "post", "put", "patch", "delete"
  input: JsonSchema;   // JSON schema for request (path params + body)
  output: JsonSchema;  // JSON schema for response
}>
```

Example introspection response:

```json
[
  {
    "name": "GetProfile",
    "path": "/api/get-profile",
    "verb": "get",
    "input": {
      "type": "object",
      "required": ["id"],
      "properties": {
        "id": { "type": "string" }
      }
    },
    "output": {
      "type": "object",
      "required": ["name", "email", "age"],
      "properties": {
        "name": { "type": "string" },
        "email": {
          "type": "string",
          "format": "email",
          "pattern": "^(?!\\.)(?!.*\\.\\.)([a-z0-9_'+\\-\\.]*)[a-z0-9_+\\-]@([a-z0-9][a-z0-9\\-]*\\.)+[a-z]{2,}$"
        },
        "age": { "type": "integer" }
      }
    }
  },
  {
    "name": "UpdateProfile",
    "path": "/api/profile/:id",
    "verb": "put",
    "input": {
      "type": "object",
      "required": ["id", "name"],
      "properties": {
        "id": { "type": "string" },
        "name": { "type": "string" }
      }
    },
    "output": {
      "type": "object",
      "required": ["id", "name"],
      "properties": {
        "id": { "type": "string" },
        "name": { "type": "string" }
      }
    }
  }
]
```

## Generated Code Structure

The generated file includes:

1. **Zod Schemas** - Validation schemas for each endpoint
2. **TypeScript Types** - Inferred types from Zod schemas (`<Name>Args` and `<Name>Result`)
3. **API Functions** - Async functions that validate and call the API
4. **Configuration** - `configure()` function to set base URL and headers
5. **Schemas Export** - All Zod schemas exported for reuse

Example generated code:

```typescript
import { z } from "zod";

// Zod Schema for input validation
export const GetProfileArgsSchema = z.object({
  id: z.string(),
});
export type GetProfileArgs = z.infer<typeof GetProfileArgsSchema>;

// Zod Schema for output validation
export const GetProfileResultSchema = z.object({
  name: z.string(),
  email: z.string().email(),
  age: z.number().int(),
});
export type GetProfileResult = z.infer<typeof GetProfileResultSchema>;

// API Function with validation
export async function getProfile(args: GetProfileArgs): Promise<GetProfileResult> {
  const validated = GetProfileArgsSchema.parse(args);
  
  const response = await fetch(`${baseUrl}/api/get-profile`, {
    method: "GET",
    headers: { "Content-Type": "application/json", ...getHeaders() },
  });
  
  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`);
  }
  
  const rawData = await response.json();
  return GetProfileResultSchema.parse(rawData);  // Runtime validation!
}

// Configuration
export interface YuzuClientConfig {
  baseUrl?: string;
  headers?: Record<string, string> | (() => Record<string, string>);
}

export function configure(config: YuzuClientConfig): void {
  // ...implementation
}

// All schemas exported
export const schemas = {
  GetProfileArgsSchema,
  GetProfileResultSchema,
};
```

## Zod Validation Features

The generator supports full JSON Schema to Zod conversion:

- **String validation** - min/max length, regex patterns, email/url/uuid formats
- **Number validation** - min/max values, integer, multipleOf
- **Array validation** - min/max items, unique items
- **Object validation** - required/optional properties, additionalProperties
- **Union types** - anyOf, oneOf (converted to z.union)
- **Enum types** - JSON Schema enums to z.enum
- **Nested objects** - Fully supported recursive types

## Development

```bash
# Run tests
bun test

# Run the CLI locally
bun run ./bin/yuzu-codegen.ts
```

This project was created using [Bun](https://bun.com).