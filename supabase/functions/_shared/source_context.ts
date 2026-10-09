const STOP_WORDS = new Set([
  "acaba", "ama", "ancak", "bana", "ben", "beni", "benim", "bir", "biri", "biz", "bunu",
  "bu", "da", "daha", "de", "diye", "gibi", "hangi", "için", "ile", "ise", "mı", "mi", "mu",
  "mü", "nasıl", "neden", "ne", "olan", "olarak", "sonra", "şu", "ve", "veya", "the", "this",
  "that", "what", "when", "where", "which", "with", "from",
]);

function normalize(value: string): string {
  return value.replaceAll("İ", "i").replaceAll("I", "ı").toLocaleLowerCase("tr-TR");
}

function terms(value: string): string[] {
  const found = normalize(value).match(/[a-zçğıöşü0-9]{4,}/gu) ?? [];
  return [...new Set(found.filter((term) => !STOP_WORDS.has(term)))];
}

function hardSplit(value: string, maxChars: number): string[] {
  const out: string[] = [];
  let rest = value.trim();
  while (rest.length > maxChars) {
    let cut = rest.lastIndexOf(" ", maxChars);
    if (cut < Math.floor(maxChars * 0.6)) cut = maxChars;
    out.push(rest.slice(0, cut).trim());
    rest = rest.slice(cut).trim();
  }
  if (rest) out.push(rest);
  return out;
}

export function splitSourceText(source: string, maxChunkChars = 12000): string[] {
  if (!Number.isInteger(maxChunkChars) || maxChunkChars < 1000) {
    throw new Error("invalid_max_chunk_chars");
  }
  const normalized = source.replace(/\r\n?/g, "\n").trim();
  if (!normalized) return [];
  if (normalized.length <= maxChunkChars) return [normalized];

  const rawParts = normalized
    .split(/\n{2,}|(?<=[.!?])\s+/u)
    .map((part) => part.trim())
    .filter(Boolean)
    .flatMap((part) => part.length > maxChunkChars ? hardSplit(part, maxChunkChars) : [part]);

  const chunks: string[] = [];
  let current = "";
  for (const part of rawParts) {
    const candidate = current ? current + "\n\n" + part : part;
    if (candidate.length <= maxChunkChars) {
      current = candidate;
      continue;
    }
    if (current) chunks.push(current);
    current = part;
  }
  if (current) chunks.push(current);
  return chunks;
}

function evenlySample(chunks: string[], count: number): number[] {
  if (chunks.length <= count) return chunks.map((_, index) => index);
  const indices = new Set<number>();
  for (let i = 0; i < count; i++) {
    indices.add(Math.round((i * (chunks.length - 1)) / Math.max(1, count - 1)));
  }
  return [...indices];
}

export function selectRelevantSourceContext(source: string, query: string, maxChars = 24000): string {
  if (!Number.isInteger(maxChars) || maxChars < 4000) {
    throw new Error("invalid_max_context_chars");
  }
  const normalized = source.replace(/\r\n?/g, "\n").trim();
  if (normalized.length <= maxChars) return normalized;

  const passageChars = Math.min(2400, Math.max(1200, Math.floor(maxChars / 8)));
  const passages = splitSourceText(normalized, passageChars);
  if (passages.length === 0) return "";

  const queryTerms = terms(query);
  const ranked = passages.map((text, index) => {
    const haystack = normalize(text);
    let score = 0;
    for (const term of queryTerms) {
      if (haystack.includes(term)) score += Math.min(term.length, 12);
    }
    return { index, text, score };
  });

  const chosen = new Set<number>();
  let used = 0;
  for (const index of evenlySample(passages, Math.min(2, passages.length))) {
    const cost = passages[index].length + (chosen.size === 0 ? 0 : 2);
    if (used + cost <= maxChars) {
      chosen.add(index);
      used += cost;
    }
  }

  const positives = ranked
    .filter((item) => item.score > 0)
    .sort((a, b) => b.score - a.score || a.index - b.index);
  const candidates = positives.length > 0
    ? positives
    : evenlySample(passages, Math.min(8, passages.length)).map((index) => ranked[index]);

  for (const item of candidates) {
    if (chosen.has(item.index)) continue;
    const cost = item.text.length + (chosen.size === 0 ? 0 : 2);
    if (used + cost > maxChars) continue;
    chosen.add(item.index);
    used += cost;
  }

  const seeds = [...chosen];
  for (let distance = 1; used < maxChars && distance <= 4; distance++) {
    for (const seed of seeds) {
      for (const index of [seed - distance, seed + distance]) {
        if (index < 0 || index >= passages.length || chosen.has(index)) continue;
        const cost = passages[index].length + (chosen.size === 0 ? 0 : 2);
        if (used + cost > maxChars) continue;
        chosen.add(index);
        used += cost;
      }
    }
  }

  return [...chosen]
    .sort((a, b) => a - b)
    .map((index) => passages[index])
    .join("\n\n")
    .slice(0, maxChars)
    .trim();
}


export function isPartialSourceContext(source: string, selectedContext: string): boolean {
  const normalizedSource = source.replace(/\r\n?/g, "\n").trim();
  const normalizedContext = selectedContext.replace(/\r\n?/g, "\n").trim();
  return normalizedContext.length < normalizedSource.length;
}
