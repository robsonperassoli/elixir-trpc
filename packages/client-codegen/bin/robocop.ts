#!/usr/bin/env bun
import { loadConfig } from "../src/config.ts";
import {
  fetchIntrospection,
  fetchIntrospectionWithRetries,
} from "../src/fetcher.ts";
import { generateCode } from "../src/generator.ts";
import { parseArgs } from "node:util";

const { values } = parseArgs({
  args: Bun.argv,
  options: {
    config: {
      type: "string",
      short: "c",
    },
    watch: {
      type: "boolean",
      short: "w",
    },
    help: {
      type: "boolean",
      short: "h",
    },
  },
  strict: true,
  allowPositionals: true,
});

if (values.help) {
  console.log(`
Usage: robocop [options]

Options:
  -c, --config <path>   Path to config file (robocop.config.ts|js|json)
  -w, --watch          Watch mode - regenerate on changes
  -h, --help           Show this help message

Examples:
  robocop                      # Generate with default config
  robocop -c robocop.config.ts # Use specific config file
  robocop --watch              # Watch mode

Config file example (robocop.config.ts):
  export default {
    introspectionUrl: "http://localhost:4000/api/inspect/robocop",
    outputDir: "./src/gen",
    outputFile: "robocop.ts",
    baseUrl: "http://localhost:4000",
  };
`);
  process.exit(0);
}

async function main() {
  try {
    const config = await loadConfig(values.config);

    console.log(`🔍 Fetching introspection from ${config.introspectionUrl}...`);

    let routes;
    if (config.introspectionFile) {
      const file = Bun.file(config.introspectionFile);
      if (!(await file.exists())) {
        throw new Error(
          `Introspection file not found: ${config.introspectionFile}`,
        );
      }
      routes = await file.json();
    } else {
      routes = await fetchIntrospectionWithRetries(config.introspectionUrl);
    }

    console.log(`✅ Found ${routes.length} routes`);

    console.log("📝 Generating TypeScript code...");
    const baseUrl = config.baseUrl ?? "http://localhost:4000";
    const generatedCode = generateCode(routes, { baseUrl });

    // Ensure output directory exists
    await Bun.write(`${config.outputDir}/.keep`, "");

    const outputPath = `${config.outputDir}/${config.outputFile}`;
    await Bun.write(outputPath, generatedCode);

    console.log(`✅ Generated ${outputPath}`);

    if (values.watch) {
      console.log("👀 Watching for changes... (Press Ctrl+C to stop)");
      // Simple watch - refetch every 5 seconds
      setInterval(async () => {
        try {
          const newRoutes = await fetchIntrospection(config.introspectionUrl);
          const newCode = generateCode(newRoutes, { baseUrl });
          const currentCode = await Bun.file(outputPath).text();

          if (newCode !== currentCode) {
            await Bun.write(outputPath, newCode);
            console.log(
              `🔄 Regenerated ${outputPath} at ${new Date().toLocaleTimeString()}`,
            );
          }
        } catch (error) {
          console.error("Watch error:", error);
        }
      }, 5000);
    }
  } catch (error) {
    console.error("❌ Error:", error instanceof Error ? error.message : error);
    process.exit(1);
  }
}

main();
