// Introspection Schema Types

export interface JsonSchema {
  type?:
    | "string"
    | "number"
    | "integer"
    | "boolean"
    | "array"
    | "object"
    | "null";
  format?: string;
  pattern?: string;
  enum?: (string | number | boolean)[];
  items?: JsonSchema;
  properties?: Record<string, JsonSchema>;
  required?: string[];
  $ref?: string;
  $schema?: string;
  description?: string;
  nullable?: boolean;
  additionalProperties?: boolean | JsonSchema;
  allOf?: JsonSchema[];
  anyOf?: JsonSchema[];
  oneOf?: JsonSchema[];
  default?: unknown;
  minLength?: number;
  maxLength?: number;
  minimum?: number;
  maximum?: number;
  exclusiveMinimum?: number;
  exclusiveMaximum?: number;
  multipleOf?: number;
  minItems?: number;
  maxItems?: number;
  uniqueItems?: boolean;
}

export interface RouteDefinition {
  /** Unique function name for this route (e.g., "GetProfile", "UpdateUser") */
  name: string;
  /** JSON schema for the request (path params, query params, body combined) */
  input: JsonSchema;
  /** JSON schema for the response */
  output: JsonSchema;
  /** API path, can include parameters like :id */
  path: string;
  /** HTTP method */
  verb: "get" | "post" | "put" | "patch" | "delete" | "head" | "options";
}

/** Introspection response is an array of route definitions */
export type IntrospectionSchema = RouteDefinition[];
