import type {
  IntrospectionSchema,
  RouteDefinition,
  JsonSchema,
} from "./types.ts";

function pascalCase(str: string): string {
  // If string is already PascalCase (starts with uppercase, has no separators), preserve it
  if (/^[A-Z][a-zA-Z0-9]*$/.test(str)) {
    return str;
  }
  return str
    .split(/[-_\/:]+/)
    .map((s) => s.charAt(0).toUpperCase() + s.slice(1))
    .join("");
}

function camelCase(str: string): string {
  const pascal = pascalCase(str);
  return pascal.charAt(0).toLowerCase() + pascal.slice(1);
}

function extractPathParams(path: string): string[] {
  const params: string[] = [];
  const regex = /:([a-zA-Z_][a-zA-Z0-9_]*)/g;
  let match;
  while ((match = regex.exec(path)) !== null) {
    params.push(match[1]);
  }
  return params;
}

// Convert JSON Schema to Zod schema code
function jsonSchemaToZod(schema: JsonSchema, schemaName: string): string {
  if (schema.$ref) {
    const refName = schema.$ref.split("/").pop() || "Unknown";
    return `${refName}Schema`;
  }

  if (schema.type === "string") {
    if (schema.enum) {
      const values = schema.enum.map((e) => `"${e}"`).join(", ");
      return `z.enum([${values}])`;
    }
    let zodCode = "z.string()";
    if (schema.minLength !== undefined) {
      zodCode += `.min(${schema.minLength})`;
    }
    if (schema.maxLength !== undefined) {
      zodCode += `.max(${schema.maxLength})`;
    }
    if (schema.pattern) {
      zodCode += `.regex(/${schema.pattern}/)`;
    }
    if (schema.format === "email") {
      zodCode += `.email()`;
    }
    if (schema.format === "url") {
      zodCode += `.url()`;
    }
    if (schema.format === "uuid") {
      zodCode += `.uuid()`;
    }
    return zodCode;
  }

  if (schema.type === "number" || schema.type === "integer") {
    let zodCode = "z.number()";
    if (schema.type === "integer") {
      zodCode += ".int()";
    }
    if (schema.minimum !== undefined) {
      zodCode += `.min(${schema.minimum})`;
    }
    if (schema.maximum !== undefined) {
      zodCode += `.max(${schema.maximum})`;
    }
    if (schema.exclusiveMinimum !== undefined) {
      zodCode += `.gt(${schema.exclusiveMinimum})`;
    }
    if (schema.exclusiveMaximum !== undefined) {
      zodCode += `.lt(${schema.exclusiveMaximum})`;
    }
    if (schema.multipleOf !== undefined) {
      zodCode += `.multipleOf(${schema.multipleOf})`;
    }
    return zodCode;
  }

  if (schema.type === "boolean") {
    return "z.boolean()";
  }

  if (schema.type === "array" && schema.items) {
    const itemSchema = jsonSchemaToZod(schema.items, `${schemaName}Item`);
    let zodCode = `z.array(${itemSchema})`;
    if (schema.minItems !== undefined) {
      zodCode += `.min(${schema.minItems})`;
    }
    if (schema.maxItems !== undefined) {
      zodCode += `.max(${schema.maxItems})`;
    }
    if (schema.uniqueItems) {
      zodCode += `.refine((arr) => new Set(arr).size === arr.length, { message: "Array must contain unique items" })`;
    }
    return zodCode;
  }

  if (
    schema.type === "object" ||
    (!schema.type && (schema.properties || schema.additionalProperties))
  ) {
    const properties: string[] = [];
    const required = schema.required || [];

    if (schema.properties) {
      for (const [key, prop] of Object.entries(schema.properties)) {
        const isRequired = required.includes(key);
        const propSchema = jsonSchemaToZod(
          prop,
          `${schemaName}${pascalCase(key)}`,
        );
        if (isRequired) {
          properties.push(`  ${key}: ${propSchema}`);
        } else {
          properties.push(`  ${key}: ${propSchema}.optional()`);
        }
      }
    }

    if (properties.length === 0) {
      return "z.record(z.any())";
    }

    return `z.object({
${properties.join(",\n")}
})`;
  }

  if (schema.anyOf) {
    const schemas = schema.anyOf.map((s, i) =>
      jsonSchemaToZod(s, `${schemaName}AnyOf${i}`),
    );
    return `z.union([${schemas.join(", ")}])`;
  }

  if (schema.allOf) {
    // Merge all schemas into one object
    const schemas = schema.allOf.map((s, i) =>
      jsonSchemaToZod(s, `${schemaName}AllOf${i}`),
    );
    return `z.intersection(${schemas.join(", ")})`;
  }

  if (schema.oneOf) {
    const schemas = schema.oneOf.map((s, i) =>
      jsonSchemaToZod(s, `${schemaName}OneOf${i}`),
    );
    return `z.union([${schemas.join(", ")}])`;
  }

  if (schema.nullable) {
    return `z.null()`;
  }

  return "z.any()";
}

// Generate TypeScript type from JSON Schema for inference from Zod
function generateTypeFromSchema(schema: JsonSchema, typeName: string): string {
  if (schema.$ref) {
    const refName = schema.$ref.split("/").pop() || "Unknown";
    return refName;
  }

  if (schema.type === "string") {
    if (schema.enum) {
      return schema.enum.map((e) => `"${e}"`).join(" | ");
    }
    return "string";
  }

  if (schema.type === "number" || schema.type === "integer") {
    return "number";
  }

  if (schema.type === "boolean") {
    return "boolean";
  }

  if (schema.type === "array" && schema.items) {
    return `Array<${generateTypeFromSchema(schema.items, `${typeName}Item`)}>`;
  }

  if (
    schema.type === "object" ||
    (!schema.type && (schema.properties || schema.additionalProperties))
  ) {
    if (!schema.properties || Object.keys(schema.properties).length === 0) {
      if (schema.additionalProperties) {
        return "Record<string, unknown>";
      }
      return "Record<string, never>";
    }

    const lines: string[] = [];
    for (const [key, prop] of Object.entries(schema.properties)) {
      const isRequired = schema.required?.includes(key) ?? false;
      const optional = isRequired ? "" : "?";
      const propType = generateTypeFromSchema(
        prop,
        `${typeName}${pascalCase(key)}`,
      );
      lines.push(`  ${key}${optional}: ${propType};`);
    }

    if (schema.additionalProperties === true) {
      lines.push("  [key: string]: unknown;");
    } else if (typeof schema.additionalProperties === "object") {
      const additionalType = generateTypeFromSchema(
        schema.additionalProperties,
        `${typeName}Additional`,
      );
      lines.push(`  [key: string]: ${additionalType};`);
    }

    return `{\n${lines.join("\n")}\n}`;
  }

  if (schema.anyOf) {
    return schema.anyOf
      .map((s, i) => generateTypeFromSchema(s, `${typeName}AnyOf${i}`))
      .join(" | ");
  }

  if (schema.allOf) {
    const merged = schema.allOf.reduce(
      (acc, s) => {
        if (s.type === "object" && s.properties) {
          return {
            type: "object",
            properties: { ...acc.properties, ...s.properties },
            required: [...(acc.required || []), ...(s.required || [])],
          } as JsonSchema;
        }
        return acc;
      },
      { type: "object", properties: {}, required: [] } as JsonSchema,
    );
    return generateTypeFromSchema(merged, typeName);
  }

  if (schema.oneOf) {
    return schema.oneOf
      .map((s, i) => generateTypeFromSchema(s, `${typeName}OneOf${i}`))
      .join(" | ");
  }

  if (schema.nullable) {
    return "null";
  }

  return "unknown";
}

function generateClientFunction(
  route: RouteDefinition,
  functionName: string,
): string {
  const pascalName = pascalCase(route.name);
  const camelName = camelCase(functionName);
  const pathParams = extractPathParams(route.path);

  const lines: string[] = [];

  // Function signature
  lines.push(
    `export async function ${camelName}(args: ${pascalName}Args): Promise<${pascalName}Result> {`,
  );

  // Validate input with Zod
  lines.push(`  // Validate input`);
  lines.push(`  const validated = ${pascalName}ArgsSchema.parse(args);`);
  lines.push(``);

  // Build URL
  let urlPath = route.path;
  if (pathParams.length > 0) {
    urlPath = route.path.replace(
      /:([a-zA-Z_][a-zA-Z0-9_]*)/g,
      "${validated.$1}",
    );
    lines.push(`  // Build URL with path params`);
    lines.push(`  const url = \`\${baseUrl}${urlPath}\`;`);
  } else {
    lines.push(`  // Build URL`);
    lines.push(`  const url = \`\${baseUrl}${urlPath}\`;`);
  }
  lines.push(``);

  // Make fetch call
  lines.push(`  // Make request`);
  lines.push(`  const response = await fetch(url, {`);
  lines.push(`    method: "${route.verb.toUpperCase()}",`);
  lines.push(`    headers: {`);
  lines.push(`      "Content-Type": "application/json",`);
  lines.push(`      ...getHeaders(),`);
  lines.push(`    },`);

  // Add body for non-GET requests
  if (route.verb !== "get" && route.verb !== "head") {
    lines.push(`    body: JSON.stringify(validated),`);
  }

  lines.push(`  });`);
  lines.push(``);

  // Handle response
  lines.push(`  // Handle response`);
  lines.push(`  if (!response.ok) {`);
  lines.push(
    `    throw new Error(\`HTTP error! status: \${response.status}\`);`,
  );
  lines.push(`  }`);
  lines.push(``);

  // Parse and validate with Zod
  lines.push(`  // Parse and validate response`);
  lines.push(`  const rawData = await response.json();`);
  lines.push(`  return ${pascalName}ResultSchema.parse(rawData);`);

  lines.push(`}`);
  lines.push(``);

  return lines.join("\n");
}

export function generateCode(
  routes: IntrospectionSchema,
  config: { baseUrl: string },
): string {
  const lines: string[] = [];

  // Header
  lines.push(
    `// This file is auto-generated by yuzu-codegen. Do not edit manually.`,
  );
  lines.push(`// Generated at: ${new Date().toISOString()}`);
  lines.push(``);
  lines.push(`import { z } from "zod";`);
  lines.push(``);

  // Generate Zod schemas and types for each route
  for (const route of routes) {
    const pascalName = pascalCase(route.name);

    // Generate Zod schema for input (ArgsSchema)
    const inputZodSchema = jsonSchemaToZod(route.input, `${pascalName}Args`);
    lines.push(`// ${route.name} - ${route.verb.toUpperCase()} ${route.path}`);
    lines.push(`export const ${pascalName}ArgsSchema = ${inputZodSchema};`);
    lines.push(
      `export type ${pascalName}Args = z.infer<typeof ${pascalName}ArgsSchema>;`,
    );
    lines.push(``);

    // Generate Zod schema for output (ResultSchema)
    const outputZodSchema = jsonSchemaToZod(
      route.output,
      `${pascalName}Result`,
    );
    lines.push(`export const ${pascalName}ResultSchema = ${outputZodSchema};`);
    lines.push(
      `export type ${pascalName}Result = z.infer<typeof ${pascalName}ResultSchema>;`,
    );
    lines.push(``);
  }

  // Configuration type
  lines.push(`// Client Configuration`);
  lines.push(`export interface YuzuClientConfig {`);
  lines.push(`  baseUrl?: string;`);
  lines.push(
    `  headers?: Record<string, string> | (() => Record<string, string>);`,
  );
  lines.push(`}`);
  lines.push(``);

  // Module-level state
  lines.push(`// Module state`);
  lines.push(`let baseUrl = "${config.baseUrl}";`);
  lines.push(`let getHeaders: () => Record<string, string> = () => ({});`);
  lines.push(``);

  // Configure function
  lines.push(`// Configure the client`);
  lines.push(`export function configure(config: YuzuClientConfig): void {`);
  lines.push(`  if (config.baseUrl !== undefined) {`);
  lines.push(`    baseUrl = config.baseUrl;`);
  lines.push(`  }`);
  lines.push(`  if (config.headers !== undefined) {`);
  lines.push(`    if (typeof config.headers === "function") {`);
  lines.push(`      getHeaders = config.headers;`);
  lines.push(`    } else {`);
  lines.push(
    `      getHeaders = () => config.headers as Record<string, string>;`,
  );
  lines.push(`    }`);
  lines.push(`  }`);
  lines.push(`}`);
  lines.push(``);

  // Generate API functions
  lines.push(`// API Functions`);
  lines.push(``);

  for (const route of routes) {
    const functionName = camelCase(route.name);
    lines.push(generateClientFunction(route, functionName));
  }

  // Export all schemas
  lines.push(`// Re-export all schemas`);
  lines.push(`export const schemas = {`);
  for (const route of routes) {
    const pascalName = pascalCase(route.name);
    lines.push(`  ${pascalName}ArgsSchema,`);
    lines.push(`  ${pascalName}ResultSchema,`);
  }
  lines.push(`};`);
  lines.push(``);

  // Default export
  lines.push(`export default {`);
  lines.push(`  configure,`);
  for (const route of routes) {
    const functionName = camelCase(route.name);
    lines.push(`  ${functionName},`);
  }
  lines.push(`};`);

  return lines.join("\n");
}
