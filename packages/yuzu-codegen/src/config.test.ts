import { test, expect, describe } from "bun:test";
import { loadConfig, defaultConfig } from "./config.ts";
import { mkdtempSync, writeFileSync, rmdirSync, unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

describe("config", () => {
  describe("defaultConfig", () => {
    test("has correct default values", () => {
      expect(defaultConfig.introspectionUrl).toBe(
        "http://localhost:4000/api/inspect/yuzu",
      );
      expect(defaultConfig.outputDir).toBe("./src/gen");
      expect(defaultConfig.outputFile).toBe("yuzu-client.ts");
    });
  });

  describe("loadConfig", () => {
    test("returns default config when no config file exists", async () => {
      const config = await loadConfig();
      expect(config.introspectionUrl).toBe(defaultConfig.introspectionUrl);
      expect(config.outputDir).toBe(defaultConfig.outputDir);
      expect(config.outputFile).toBe(defaultConfig.outputFile);
    });

    test("loads JSON config file", async () => {
      const tmpDir = mkdtempSync(join(tmpdir(), "yuzu-codegen-test-"));
      const configPath = join(tmpDir, "yuzu-codegen.config.json");

      const customConfig = {
        introspectionUrl: "http://example.com/api/inspect",
        outputDir: "./custom/gen",
        outputFile: "api.ts",
      };

      writeFileSync(configPath, JSON.stringify(customConfig));

      const config = await loadConfig(configPath);

      expect(config.introspectionUrl).toBe(customConfig.introspectionUrl);
      expect(config.outputDir).toBe(customConfig.outputDir);
      expect(config.outputFile).toBe(customConfig.outputFile);

      unlinkSync(configPath);
      rmdirSync(tmpDir);
    });

    test("merges user config with defaults", async () => {
      const tmpDir = mkdtempSync(join(tmpdir(), "yuzu-codegen-test-"));
      const configPath = join(tmpDir, "yuzu-codegen.config.json");

      const customConfig = {
        introspectionUrl: "http://custom.com/api",
      };

      writeFileSync(configPath, JSON.stringify(customConfig));

      const config = await loadConfig(configPath);

      expect(config.introspectionUrl).toBe("http://custom.com/api");
      expect(config.outputDir).toBe(defaultConfig.outputDir); // From defaults
      expect(config.outputFile).toBe(defaultConfig.outputFile); // From defaults

      unlinkSync(configPath);
      rmdirSync(tmpDir);
    });
  });
});
