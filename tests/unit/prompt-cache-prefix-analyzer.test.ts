import test from "node:test";
import assert from "node:assert/strict";
import { generatePromptCacheKey } from "../../src/lib/promptCache/prefixAnalyzer.ts";

test("generatePromptCacheKey includes role changes in the prefix hash", () => {
  const systemPrefix = [{ role: "system", content: "shared instructions" }];
  const assistantPrefix = [{ role: "assistant", content: "shared instructions" }];

  assert.notEqual(generatePromptCacheKey(systemPrefix), generatePromptCacheKey(assistantPrefix));
});

test("generatePromptCacheKey returns stable keys for repeated analysis", () => {
  const messages = [
    { role: "system", content: "You are helpful." },
    { role: "assistant", content: "Previous reusable context." },
    { role: "user", content: "Question" },
  ];

  const first = generatePromptCacheKey(messages);
  const second = generatePromptCacheKey(messages);

  assert.equal(first, second);
  assert.match(first, /^omni-[a-f0-9]{32}$/);
});
