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

  // Optional: Use a local JSON file instead of fetching from URL
  // introspectionFile: "./introspection.json",

  // Optional: Additional headers for the introspection request
  // headers: {
  //   "Authorization": "Bearer token",
  // },
} satisfies YuzuCodegenConfig;
