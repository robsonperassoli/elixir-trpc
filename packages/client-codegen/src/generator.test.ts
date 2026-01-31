import { test, expect, describe } from "bun:test";
import { generateCode } from "./generator.ts";
import type { RouteDefinition } from "./types.ts";

describe("generator", () => {
  describe("generateCode", () => {
    test("generates Zod schemas and types for a route", () => {
      const routes: RouteDefinition[] = [
        {
          name: "GetProfile",
          path: "/api/profile",
          verb: "get",
          input: {
            type: "object",
            required: ["id"],
            properties: {
              id: { type: "string" },
            },
          },
          output: {
            type: "object",
            required: ["name", "email"],
            properties: {
              name: { type: "string" },
              email: { type: "string" },
            },
          },
        },
      ];

      const code = generateCode(routes, { baseUrl: "http://localhost:4000" });

      // Should import zod
      expect(code).toContain('import { z } from "zod"');

      // Should generate Zod schemas
      expect(code).toContain("export const GetProfileArgsSchema = ");
      expect(code).toContain("export const GetProfileResultSchema = ");

      // Should generate types from Zod inference
      expect(code).toContain(
        "export type GetProfileArgs = z.infer<typeof GetProfileArgsSchema>",
      );
      expect(code).toContain(
        "export type GetProfileResult = z.infer<typeof GetProfileResultSchema>",
      );

      // Should generate function with correct signature
      expect(code).toContain(
        "export async function getProfile(args: GetProfileArgs): Promise<GetProfileResult>",
      );

      // Should validate input with Zod
      expect(code).toContain(
        "const validated = GetProfileArgsSchema.parse(args)",
      );

      // Should validate output with Zod
      expect(code).toContain("return GetProfileResultSchema.parse(rawData)");
    });

    test("generates correct Zod schema for string types", () => {
      const routes: RouteDefinition[] = [
        {
          name: "TestStrings",
          path: "/api/test",
          verb: "get",
          input: {
            type: "object",
            properties: {
              simple: { type: "string" },
              email: { type: "string", format: "email" },
              url: { type: "string", format: "url" },
              uuid: { type: "string", format: "uuid" },
              pattern: { type: "string", pattern: "^[a-z]+$" },
              minMax: { type: "string", minLength: 2, maxLength: 10 },
            },
          },
          output: { type: "object", properties: {} },
        },
      ];

      const code = generateCode(routes, { baseUrl: "http://localhost:4000" });

      expect(code).toContain("z.string()");
      expect(code).toContain("z.string().email()");
      expect(code).toContain("z.string().url()");
      expect(code).toContain("z.string().uuid()");
      expect(code).toContain("z.string().regex(/");
      expect(code).toContain("z.string().min(2)");
      expect(code).toContain(".max(10)");
    });

    test("generates correct Zod schema for number types", () => {
      const routes: RouteDefinition[] = [
        {
          name: "TestNumbers",
          path: "/api/test",
          verb: "get",
          input: {
            type: "object",
            properties: {
              simple: { type: "number" },
              integer: { type: "integer" },
              min: { type: "number", minimum: 0 },
              max: { type: "number", maximum: 100 },
              gt: { type: "number", exclusiveMinimum: 0 },
              lt: { type: "number", exclusiveMaximum: 100 },
              multiple: { type: "integer", multipleOf: 5 },
            },
          },
          output: { type: "object", properties: {} },
        },
      ];

      const code = generateCode(routes, { baseUrl: "http://localhost:4000" });

      expect(code).toContain("z.number()");
      expect(code).toContain("z.number().int()");
      expect(code).toContain("z.number().min(0)");
      expect(code).toContain("z.number().max(100)");
      expect(code).toContain("z.number().gt(0)");
      expect(code).toContain("z.number().lt(100)");
      expect(code).toContain("z.number().int().multipleOf(5)");
    });

    test("generates correct Zod schema for enum types", () => {
      const routes: RouteDefinition[] = [
        {
          name: "TestEnum",
          path: "/api/test",
          verb: "get",
          input: {
            type: "object",
            properties: {
              status: {
                type: "string",
                enum: ["active", "inactive", "pending"],
              },
            },
          },
          output: { type: "object", properties: {} },
        },
      ];

      const code = generateCode(routes, { baseUrl: "http://localhost:4000" });

      expect(code).toContain('z.enum(["active", "inactive", "pending"])');
    });

    test("generates correct Zod schema for array types", () => {
      const routes: RouteDefinition[] = [
        {
          name: "TestArray",
          path: "/api/test",
          verb: "get",
          input: {
            type: "object",
            properties: {
              items: {
                type: "array",
                items: { type: "string" },
                minItems: 1,
                maxItems: 10,
              },
            },
          },
          output: { type: "object", properties: {} },
        },
      ];

      const code = generateCode(routes, { baseUrl: "http://localhost:4000" });

      expect(code).toContain("z.array(z.string())");
      expect(code).toContain(".min(1)");
      expect(code).toContain(".max(10)");
    });

    test("generates correct Zod schema for nested objects", () => {
      const routes: RouteDefinition[] = [
        {
          name: "TestNested",
          path: "/api/test",
          verb: "get",
          input: {
            type: "object",
            properties: {
              user: {
                type: "object",
                properties: {
                  name: { type: "string" },
                  age: { type: "integer" },
                },
              },
            },
          },
          output: { type: "object", properties: {} },
        },
      ];

      const code = generateCode(routes, { baseUrl: "http://localhost:4000" });

      expect(code).toContain("z.object({");
      expect(code).toContain("user: z.object({");
      expect(code).toContain("name: z.string()");
      expect(code).toContain("age: z.number().int()");
    });

    test("handles optional properties correctly", () => {
      const routes: RouteDefinition[] = [
        {
          name: "TestOptional",
          path: "/api/test",
          verb: "get",
          input: {
            type: "object",
            required: ["id"],
            properties: {
              id: { type: "string" },
              name: { type: "string" },
              email: { type: "string" },
            },
          },
          output: { type: "object", properties: {} },
        },
      ];

      const code = generateCode(routes, { baseUrl: "http://localhost:4000" });

      expect(code).toContain("id: z.string()");
      expect(code).toContain("name: z.string().optional()");
      expect(code).toContain("email: z.string().optional()");
    });

    test("generates function with path params correctly", () => {
      const routes: RouteDefinition[] = [
        {
          name: "UpdateProfile",
          path: "/api/profile/:id",
          verb: "put",
          input: {
            type: "object",
            required: ["id", "name"],
            properties: {
              id: { type: "string" },
              name: { type: "string" },
            },
          },
          output: {
            type: "object",
            properties: {
              id: { type: "string" },
              name: { type: "string" },
            },
          },
        },
      ];

      const code = generateCode(routes, { baseUrl: "http://localhost:4000" });

      expect(code).toContain(
        "export async function updateProfile(args: UpdateProfileArgs): Promise<UpdateProfileResult>",
      );
      expect(code).toContain(
        "const url = `${baseUrl}/api/profile/${validated.id}`",
      );
    });

    test("generates configure function", () => {
      const routes: RouteDefinition[] = [];

      const code = generateCode(routes, { baseUrl: "http://localhost:4000" });

      expect(code).toContain("export interface RobocopConfig");
      expect(code).toContain(
        "export function configure(config: RobocopConfig): void",
      );
      expect(code).toContain("let baseUrl = ");
      expect(code).toContain("let getHeaders: () => Record<string, string>");
    });

    test("generates schemas export object", () => {
      const routes: RouteDefinition[] = [
        {
          name: "GetUser",
          path: "/api/user",
          verb: "get",
          input: { type: "object", properties: {} },
          output: { type: "object", properties: {} },
        },
        {
          name: "CreateUser",
          path: "/api/user",
          verb: "post",
          input: { type: "object", properties: {} },
          output: { type: "object", properties: {} },
        },
      ];

      const code = generateCode(routes, { baseUrl: "http://localhost:4000" });

      expect(code).toContain("export const schemas = {");
      expect(code).toContain("GetUserArgsSchema,");
      expect(code).toContain("GetUserResultSchema,");
      expect(code).toContain("CreateUserArgsSchema,");
      expect(code).toContain("CreateUserResultSchema,");
    });

    test("generates default export object", () => {
      const routes: RouteDefinition[] = [
        {
          name: "GetUser",
          path: "/api/user",
          verb: "get",
          input: { type: "object", properties: {} },
          output: { type: "object", properties: {} },
        },
      ];

      const code = generateCode(routes, { baseUrl: "http://localhost:4000" });

      expect(code).toContain("export default {");
      expect(code).toContain("configure,");
      expect(code).toContain("getUser,");
    });

    test("handles different HTTP verbs correctly", () => {
      const routes: RouteDefinition[] = [
        {
          name: "ListUsers",
          path: "/api/users",
          verb: "get",
          input: { type: "object", properties: {} },
          output: { type: "array", items: { type: "object", properties: {} } },
        },
        {
          name: "CreateUser",
          path: "/api/users",
          verb: "post",
          input: { type: "object", properties: { name: { type: "string" } } },
          output: { type: "object", properties: {} },
        },
        {
          name: "UpdateUser",
          path: "/api/users/:id",
          verb: "put",
          input: {
            type: "object",
            properties: { id: { type: "string" }, name: { type: "string" } },
          },
          output: { type: "object", properties: {} },
        },
        {
          name: "PatchUser",
          path: "/api/users/:id",
          verb: "patch",
          input: {
            type: "object",
            properties: { id: { type: "string" }, name: { type: "string" } },
          },
          output: { type: "object", properties: {} },
        },
        {
          name: "DeleteUser",
          path: "/api/users/:id",
          verb: "delete",
          input: { type: "object", properties: { id: { type: "string" } } },
          output: { type: "object", properties: {} },
        },
      ];

      const code = generateCode(routes, { baseUrl: "http://localhost:4000" });

      expect(code).toContain('method: "GET"');
      expect(code).toContain('method: "POST"');
      expect(code).toContain('method: "PUT"');
      expect(code).toContain('method: "PATCH"');
      expect(code).toContain('method: "DELETE"');

      // GET should not have body
      expect(code).toContain(
        "export async function listUsers(args: ListUsersArgs): Promise<ListUsersResult>",
      );

      // POST, PUT, PATCH should have body
      expect(code).toContain("body: JSON.stringify(validated)");
    });

    test("includes auto-generated header comment", () => {
      const routes: RouteDefinition[] = [];

      const code = generateCode(routes, { baseUrl: "http://localhost:4000" });

      expect(code).toContain(
        "// This file is auto-generated by robocop. Do not edit manually.",
      );
      expect(code).toContain("// Generated at:");
    });

    test("handles additionalProperties correctly", () => {
      const routes: RouteDefinition[] = [
        {
          name: "TestAdditional",
          path: "/api/test",
          verb: "get",
          input: {
            type: "object",
            additionalProperties: true,
            properties: {
              known: { type: "string" },
            },
          },
          output: { type: "object", properties: {} },
        },
      ];

      const code = generateCode(routes, { baseUrl: "http://localhost:4000" });

      expect(code).toContain("[key: string]: z.any()");
    });

    test("handles anyOf union types", () => {
      const routes: RouteDefinition[] = [
        {
          name: "TestUnion",
          path: "/api/test",
          verb: "get",
          input: {
            type: "object",
            properties: {
              value: {
                anyOf: [{ type: "string" }, { type: "number" }],
              },
            },
          },
          output: { type: "object", properties: {} },
        },
      ];

      const code = generateCode(routes, { baseUrl: "http://localhost:4000" });

      expect(code).toContain("z.union([z.string(), z.number()])");
    });

    test("handles boolean type", () => {
      const routes: RouteDefinition[] = [
        {
          name: "TestBoolean",
          path: "/api/test",
          verb: "get",
          input: {
            type: "object",
            properties: {
              active: { type: "boolean" },
            },
          },
          output: { type: "object", properties: {} },
        },
      ];

      const code = generateCode(routes, { baseUrl: "http://localhost:4000" });

      expect(code).toContain("z.boolean()");
    });
  });
});
