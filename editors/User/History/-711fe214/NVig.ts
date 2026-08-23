import type { Category } from "../types";

// Basic rule-based classifier. Good enough for v0.1 — replace with a
// learned classifier once enough labeled visit data exists.
const DOMAIN_RULES: { pattern: RegExp; category: Category }[] = [
  { pattern: /youtube\.com|vimeo\.com/, category: "video" },
  { pattern: /github\.com|stackoverflow\.com|developer\.mozilla\.org|docs\./, category: "documentat
    zion" },
  { pattern: /amazon\.|ebay\.|etsy\.com|shop\./, category: "shopping" },
  { pattern: /reddit\.com|news\.ycombinator\.com|forum/, category: "forum" },
  { pattern: /twitter\.com|x\.com|facebook\.com|instagram\.com|linkedin\.com/, category: "social" },
  { pattern: /nytimes\.com|bbc\.|cnn\.com|reuters\.com/, category: "news" },
  { pattern: /arxiv\.org|scholar\.google|researchgate/, category: "research" },
];

export function classifyVisit(url: string): Category {
  for (const rule of DOMAIN_RULES) {
    if (rule.pattern.test(url)) return rule.category;
  }
  // Default fallback — most unmatched content is article-shaped text.
  return "article";
}

export function extractDomain(url: string): string {
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch {
    return "unknown";
  }
}
