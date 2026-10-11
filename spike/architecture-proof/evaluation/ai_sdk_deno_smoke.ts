// LA-0012 evaluation script (NOT a product dependency). Reproduce:
//   deno run -A spike/architecture-proof/evaluation/ai_sdk_deno_smoke.ts
//   deno check spike/architecture-proof/evaluation/ai_sdk_deno_smoke.ts
//   deno bundle --minify -o /tmp/sdk.js spike/architecture-proof/evaluation/ai_sdk_deno_smoke.ts
// Local evaluation only: can the Vercel AI SDK run structured generation on Deno with a mock model?
import { generateObject, jsonSchema } from "npm:ai@7.0.118";
import { MockLanguageModelV4 } from "npm:ai@7.0.118/test";

const model = new MockLanguageModelV4({
  doGenerate: () => Promise.resolve({
    content: [{ type: "text" as const, text: JSON.stringify({ summary: "S", key_points: ["a"], language: "tr-TR" }) }],
    finishReason: { unified: "stop" as const, raw: "stop" },
    usage: {
      inputTokens: { total: 5, noCache: 5, cacheRead: 0, cacheWrite: 0 },
      outputTokens: { total: 5, text: 5, reasoning: 0 },
    },
    warnings: [],
  }),
});
const schema = jsonSchema<{ summary: string; key_points: string[]; language: string }>({
  type: "object", required: ["summary", "key_points", "language"],
  properties: { summary: { type: "string" }, key_points: { type: "array", items: { type: "string" } }, language: { type: "string" } },
});
const r = await generateObject({ model, schema, prompt: "x" });
console.log(JSON.stringify({ object: r.object, usage: r.usage }));
