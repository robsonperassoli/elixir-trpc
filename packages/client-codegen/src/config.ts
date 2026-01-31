import { join } from "node:path";

export interface RobocopConfig {
  /** URL to the introspection JSON endpoint */
  introspectionUrl: string;
  /** Base URL for API calls (defaults to introspectionUrl origin) */
  baseUrl?: string;
  /** Directory where the generated file will be saved */
  outputDir: string;
  /** Name of the generated file */
  outputFile: string;
  /** Path to the introspection JSON file (alternative to URL) */
  introspectionFile?: string;
  /** Additional headers to send with the introspection request */
  headers?: Record<string, string>;
}

export const defaultConfig: RobocopConfig = {
  introspectionUrl: "http://localhost:4000/api/inspect/robocop",
  outputDir: "./src/gen",
  outputFile: "robocop.ts",
};

export async function loadConfig(configPath?: string): Promise<RobocopConfig> {
  // Try to find config file if not provided
  if (!configPath) {
    const possiblePaths = [
      "robocop.config.ts",
      "robocop.config.js",
      "robocop.config.json",
    ];

    for (const path of possiblePaths) {
      const file = Bun.file(path);
      if (await file.exists()) {
        configPath = path;
        break;
      }
    }
  }

  if (!configPath) {
    console.log("No config file found, using defaults");
    return { ...defaultConfig };
  }

  console.log(`Loading config from ${configPath}`);
  const configFile = Bun.file(configPath);

  if (!(await configFile.exists())) {
    throw new Error(`Config file not found: ${configPath}`);
  }

  let userConfig: Partial<RobocopConfig>;

  if (configPath.endsWith(".json")) {
    userConfig = await configFile.json();
  } else {
    // For .ts and .js files, import them
    const configModule = await import(join(process.cwd(), configPath));
    userConfig = configModule.default ?? configModule;
  }

  return {
    ...defaultConfig,
    ...userConfig,
  };
}
