import js from "@eslint/js";
import tseslint from "typescript-eslint";

const nodeGlobals = {
  process: "readonly", console: "readonly", Buffer: "readonly",
  __dirname: "readonly", setTimeout: "readonly", clearTimeout: "readonly",
  setInterval: "readonly", clearInterval: "readonly", URL: "readonly",
  URLSearchParams: "readonly", TextEncoder: "readonly", TextDecoder: "readonly",
  fetch: "readonly", NodeJS: "readonly", crypto: "readonly",
};

export default tseslint.config(
  { ignores: ["dist/**", "src/generated/**", "node_modules/**"] },
  { languageOptions: { globals: nodeGlobals } },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ["**/*.ts"],
    rules: {
      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/no-non-null-assertion": "off",
      "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_", varsIgnorePattern: "^_" }],
    },
  },
);
