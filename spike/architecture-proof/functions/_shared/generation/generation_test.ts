// LA-0012 adapter-contract tests. No network: the fetch adapter receives a stub fetch.
import { deepStrictEqual as assertEquals, ok as assert } from "node:assert/strict";
import { type StructuredGenerationCapability, validateSummaryOutput } from "./contract.ts";
import { DeterministicFakeProvider } from "./fake_provider.ts";
import { FetchChatCompletionsAdapter } from "./fetch_adapter.ts";

const REQ = {
  task: "summary.v1" as const,
  attemptKey: "job-1:1",
  sourceText: "Birinci cümle. İkinci cümle! Üçüncü?",
  outputLocale: "tr-TR",
};

function stubFetch(respond: (req: Request) => Response | Promise<Response>): typeof fetch {
  return ((input: RequestInfo | URL, init?: RequestInit) => respond(new Request(input, init))) as typeof fetch;
}

function okBody(content: unknown, extra: Record<string, unknown> = {}) {
  return new Response(
    JSON.stringify({
      id: "resp_1",
      choices: [{ message: { content: JSON.stringify(content) } }],
      usage: { total_tokens: 77 },
      ...extra,
    }),
    { status: 200, headers: { "x-request-id": "req_abc" } },
  );
}

Deno.test("validateSummaryOutput accepts contract shape and rejects malformed output", () => {
  assertEquals(validateSummaryOutput({ summary: " S ", key_points: ["a"], language: "tr-TR" }), {
    summary: "S",
    keyPoints: ["a"],
    language: "tr-TR",
  });
  assertEquals(validateSummaryOutput({ summary: "", key_points: [], language: "tr-TR" }), null);
  assertEquals(validateSummaryOutput({ summary: "x", key_points: "a", language: "tr-TR" }), null);
  assertEquals(validateSummaryOutput({ summary: "x", key_points: [], language: "" }), null);
  assertEquals(validateSummaryOutput({ summary: "x", key_points: Array(31).fill("p"), language: "tr" }), null);
  assertEquals(validateSummaryOutput("not an object"), null);
});

Deno.test("fake provider is deterministic and satisfies the contract", async () => {
  const a = await new DeterministicFakeProvider().generate(REQ);
  const b = await new DeterministicFakeProvider().generate(REQ);
  assertEquals(a, b);
  assert(a.kind === "ok");
  assert(validateSummaryOutput({ ...a.output, key_points: a.output.keyPoints }) !== null);
  assertEquals(a.output.language, "tr-TR");
});

Deno.test("fake provider replays scripted failures, then succeeds", async () => {
  const p = new DeterministicFakeProvider(["retryable", "ambiguous"]);
  assertEquals((await p.generate(REQ)).kind, "failed");
  const second = await p.generate(REQ);
  assert(second.kind === "failed" && second.failureClass === "ambiguous");
  assertEquals((await p.generate(REQ)).kind, "ok");
  assertEquals(p.calls.length, 3);
});

Deno.test("fetch adapter: success maps to domain output; key and provider shapes stay inside", async () => {
  let seen: Request | undefined;
  const adapter = new FetchChatCompletionsAdapter({
    baseUrl: "https://provider.invalid/v1",
    apiKey: "sk-test-not-real",
    model: "m1",
    fetchImpl: stubFetch((req) => {
      seen = req;
      return okBody({ summary: "Özet", key_points: ["k"], language: "tr-TR" });
    }),
  });
  const r = await adapter.generate(REQ);
  assert(r.kind === "ok");
  assertEquals(r.output, { summary: "Özet", keyPoints: ["k"], language: "tr-TR" });
  assertEquals(r.executionRef, "req_abc");
  assertEquals(r.usage.totalTokens, 77);
  assertEquals(seen?.headers.get("idempotency-key"), "job-1:1");
  assert(!JSON.stringify(r).includes("sk-test-not-real"), "credential must not leak into the result");
  assertEquals(adapter.adapterRef, "fetch-chat:m1");
});

Deno.test("fetch adapter: failure classification", async () => {
  const make = (f: typeof fetch) =>
    new FetchChatCompletionsAdapter({
      baseUrl: "https://p.invalid/v1",
      apiKey: "k",
      model: "m",
      fetchImpl: f,
      timeoutMs: 50,
    });
  const cls = async (f: typeof fetch) => {
    const r = await make(f).generate(REQ);
    return r.kind === "failed" ? r.failureClass : "ok";
  };
  assertEquals(await cls(stubFetch(() => new Response("{}", { status: 429 }))), "retryable");
  assertEquals(await cls(stubFetch(() => new Response("{}", { status: 503 }))), "retryable");
  assertEquals(await cls(stubFetch(() => new Response("{}", { status: 400 }))), "final");
  assertEquals(
    await cls(stubFetch(() => {
      throw new TypeError("connection reset");
    })),
    "ambiguous",
  );
  assertEquals(
    await cls(
      stubFetch((req) =>
        new Promise((_, reject) =>
          req.signal.addEventListener("abort", () => reject(new DOMException("aborted", "AbortError")))
        )
      ),
    ),
    "ambiguous",
  );
  assertEquals(await cls(stubFetch(() => okBody({ summary: "", key_points: [], language: "tr-TR" }))), "final");
  assertEquals(await cls(stubFetch(() => new Response("not json", { status: 200 }))), "ambiguous");
});

Deno.test("fetch adapter refuses to start without a credential", () => {
  let threw = false;
  try {
    new FetchChatCompletionsAdapter({ baseUrl: "x", apiKey: "", model: "m" });
  } catch {
    threw = true;
  }
  assert(threw);
});

Deno.test("provider replacement leaves the domain output shape unchanged", async () => {
  const providers: StructuredGenerationCapability[] = [
    new DeterministicFakeProvider(),
    new FetchChatCompletionsAdapter({
      baseUrl: "https://p.invalid/v1",
      apiKey: "k",
      model: "m",
      fetchImpl: stubFetch(() => okBody({ summary: "S", key_points: ["a"], language: "tr-TR" })),
    }),
  ];
  const shapes = [];
  for (const p of providers) {
    const r = await p.generate(REQ);
    assert(r.kind === "ok");
    shapes.push(Object.keys(r.output).sort().join(","));
  }
  assertEquals(new Set(shapes).size, 1);
});

Deno.test("domain contract imports no provider SDK or adapter module", async () => {
  const src = await Deno.readTextFile(new URL("./contract.ts", import.meta.url));
  const imports = [...src.matchAll(/^import .* from ["'](.+)["']/gm)].map((m) => m[1]);
  assertEquals(imports, []);
  for (const banned of ["openai", "@ai-sdk", "npm:ai", "anthropic", "fetch_adapter"]) {
    assert(!src.includes(`from "${banned}`) && !src.includes(`"npm:${banned}`), banned);
  }
});
