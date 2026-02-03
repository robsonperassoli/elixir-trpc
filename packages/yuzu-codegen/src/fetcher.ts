import type { IntrospectionSchema, RouteDefinition } from "./types.ts";

export interface FetchOptions {
  headers?: Record<string, string>;
}

export async function fetchIntrospection(
  url: string,
  options?: FetchOptions,
): Promise<IntrospectionSchema> {
  const response = await fetch(url, {
    method: "GET",
    headers: {
      Accept: "application/json",
      ...options?.headers,
    },
  });

  if (!response.ok) {
    throw new Error(
      `Failed to fetch introspection: ${response.status} ${response.statusText}`,
    );
  }

  const result: unknown = await response.json();

  // Validate that the response is an array
  if (!Array.isArray(result)) {
    throw new Error(
      "Invalid introspection response: expected an array of routes",
    );
  }

  // Validate each route has required fields
  for (const route of result) {
    if (typeof route !== "object" || route === null) {
      throw new Error("Invalid route: expected an object");
    }
    const r = route as Record<string, unknown>;

    if (typeof r.name !== "string") {
      throw new Error("Invalid route: missing or invalid 'name'");
    }
    if (typeof r.path !== "string") {
      throw new Error("Invalid route: missing or invalid 'path'");
    }
    if (typeof r.verb !== "string") {
      throw new Error("Invalid route: missing or invalid 'verb'");
    }
    if (typeof r.input !== "object" || r.input === null) {
      throw new Error("Invalid route: missing or invalid 'input'");
    }
    if (typeof r.output !== "object" || r.output === null) {
      throw new Error("Invalid route: missing or invalid 'output'");
    }
  }

  return result as IntrospectionSchema;
}

export async function fetchIntrospectionWithRetries(
  url: string,
  options?: FetchOptions,
  retries = 3,
  delayMs = 1000,
): Promise<IntrospectionSchema> {
  let lastError: Error;

  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      return await fetchIntrospection(url, options);
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));

      if (attempt < retries - 1) {
        console.log(`Retry ${attempt + 1}/${retries} after ${delayMs}ms...`);
        await new Promise((resolve) => setTimeout(resolve, delayMs));
      }
    }
  }

  throw lastError!;
}
