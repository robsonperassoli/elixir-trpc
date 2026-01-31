robocop/docs/library-usage.md
```

# Library Usage Guide

To use **robocop** in your application, install it as a dev dependency and run it to generate the TypeScript client. Here's how:

## 1. Install Robocop

```bash
# Using Bun (recommended)
bun add -D robocop

# Using npm
npm install -D robocop

# Using yarn
yarn add -D robocop

# Using pnpm
pnpm add -D robocop

# Or install from local path/GitHub
bun add -D /path/to/robocop
```

## 2. Create Config File

Create `robocop.config.ts` in your project root:

```typescript
import type { RobocopConfig } from "robocop";

export default {
  introspectionUrl: "http://localhost:4000/api/inspect/robocop",
  baseUrl: "http://localhost:4000",
  outputDir: "./src/generated",
  outputFile: "api.ts",
} satisfies RobocopConfig;
```

## 3. Add npm Scripts

Add to your `package.json`:

```json
{
  "scripts": {
    "generate": "robocop",
    "generate:watch": "robocop --watch",
    "dev": "bun run generate && bun dev",
    "build": "bun run generate && tsc && bun build"
  }
}
```

## 4. Generate the Client

```bash
# Generate once
bun run generate

# Or watch mode (regenerates when API changes)
bun run generate:watch
```

## 5. Use in Your App

```typescript
// src/App.tsx or any component
import { configure, getProfile, updateProfile, schemas } from "./generated/api";

// Configure once (e.g., in main.tsx or App.tsx)
configure({
  baseUrl: import.meta.env.VITE_API_URL || "http://localhost:4000",
  headers: () => ({
    Authorization: `Bearer ${localStorage.getItem("token")}`,
  }),
});

// Use in components
async function loadProfile(id: string) {
  try {
    const profile = await getProfile({ id });
    // profile is fully typed and validated by Zod
    console.log(profile.name, profile.email);
  } catch (error) {
    // Zod validation errors or fetch errors
    console.error(error);
  }
}
```

## 6. Path Aliases (Optional)

If you're using a bundler like Vite, you can configure path aliases for cleaner imports:

```typescript
// vite.config.ts
import { defineConfig } from "vite";
import path from "path";

export default defineConfig({
  resolve: {
    alias: {
      "@api": path.resolve(__dirname, "./src/generated/api.ts"),
    },
  },
});
```

Then import with: `import { getProfile } from "@api";`

## 7. TypeScript Path Mapping (Optional)

Add to `tsconfig.json` for cleaner imports:

```json
{
  "compilerOptions": {
    "paths": {
      "@api/*": ["./src/generated/*"]
    }
  }
}
```

## Development Workflow

```bash
# Terminal 1: Watch API changes and regenerate
bun run generate:watch

# Terminal 2: Run dev server
bun dev
```

Or use a tool like `concurrently`:

```json
{
  "scripts": {
    "dev": "concurrently \"robocop --watch\" \"bun dev\""
  }
}
```

## Notes

- ✅ Zod is a runtime dependency - make sure to `bun add zod`
- ✅ Generated files use native `fetch()` which works in all modern browsers
- ✅ Tree-shaking works - unused API functions are removed from production builds

The generated client works seamlessly with HMR - just re-run `bun run generate` when your API changes!