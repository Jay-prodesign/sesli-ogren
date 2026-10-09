import { deepStrictEqual as assertEquals, ok as assert } from "node:assert/strict";
import {
  isPartialSourceContext,
  selectRelevantSourceContext,
  splitSourceText,
} from "./source_context.ts";

Deno.test("splitSourceText keeps short sources intact and deterministically bounds long chunks", () => {
  assertEquals(splitSourceText("Birinci cümle. İkinci cümle.", 1000), ["Birinci cümle. İkinci cümle."]);

  const long = Array.from(
    { length: 40 },
    (_, index) => `Bölüm ${index}. Bu bölüm fotosentez hakkında yeterince uzun bir açıklama içerir.`,
  ).join("\n\n");
  const chunks = splitSourceText(long, 1000);
  assert(chunks.length > 1);
  assert(chunks.every((chunk) => chunk.length <= 1000));
  assert(chunks.join("\n\n").includes("Bölüm 39."));
});

Deno.test("selectRelevantSourceContext keeps a distant query-relevant passage inside a bounded context", () => {
  const source = [
    ...Array.from({ length: 30 }, (_, index) =>
      `Genel bölüm ${index}. Hücre yapısı ve biyoloji hakkında başka bilgiler anlatılır.`
    ),
    "Fotosentez bölümünde karbondioksit ve su kullanılarak enerji dönüşümü açıklanır.",
    ...Array.from({ length: 30 }, (_, index) =>
      `Son bölüm ${index}. Genetik ve kalıtım hakkında başka bilgiler anlatılır.`
    ),
  ].join("\n\n");

  const selected = selectRelevantSourceContext(
    source,
    "Karbondioksit fotosentez sırasında nasıl kullanılır?",
    4000,
  );
  assert(selected.length <= 4000);
  assert(selected.includes("karbondioksit ve su"));
  assert(selected.length < source.length);
});

Deno.test("selectRelevantSourceContext samples a long source safely when query has no lexical match", () => {
  const source = Array.from(
    { length: 50 },
    (_, index) => `Kaynak parçası ${index}. Fotosentez ve hücre hakkında açıklama.`,
  ).join("\n\n");

  const selected = selectRelevantSourceContext(source, "mitokondriyal ribozom alt birimi", 4500);
  assert(selected.length <= 4500);
  assert(selected.includes("Kaynak parçası 0."));
  assert(selected.includes("Kaynak parçası 49."));
});

Deno.test("selectRelevantSourceContext leaves short source byte-for-byte except newline normalization", () => {
  const source = "Birinci satır.\r\nİkinci satır.";
  assertEquals(selectRelevantSourceContext(source, "ikinci", 4000), "Birinci satır.\nİkinci satır.");
});


Deno.test("isPartialSourceContext distinguishes full from bounded source context", () => {
  const shortSource = "Birinci satır.\nİkinci satır.";
  assertEquals(
    isPartialSourceContext(shortSource, selectRelevantSourceContext(shortSource, "ikinci", 4000)),
    false,
  );

  const longSource = Array.from(
    { length: 120 },
    (_, index) => `Bölüm ${index}. Fotosentez, hücre ve enerji dönüşümü hakkında ayrıntılı kaynak metni.`,
  ).join("\n\n");
  const selected = selectRelevantSourceContext(longSource, "fotosentez enerji dönüşümü", 4000);
  assertEquals(isPartialSourceContext(longSource, selected), true);
});
