import { fetchAndPersistProviderLimits } from "@/lib/usage/providerLimits";

export interface QuotaRefreshAfterProviderErrorInput {
  connectionId: string | null | undefined;
  provider?: string | null;
  status?: number | null;
  errorText?: string | null;
  reason?: string | null;
}

const THROTTLE_MS = 90_000;
const MAX_CONCURRENT_REFRESHES = 3;
const QUOTA_ERROR_TEXT = /\b(quota|credits?|usage[_\s-]*limit|rate[_\s-]*limit|limit(?:ed)?|exhausted)\b/i;

const lastScheduledAt = new Map<string, number>();
const pending = new Map<string, QuotaRefreshAfterProviderErrorInput>();
let activeCount = 0;

function shouldRefreshForError(input: QuotaRefreshAfterProviderErrorInput): boolean {
  const status = Number(input.status || 0);
  if (status === 429 || status === 402) return true;
  const text = `${input.errorText || ""} ${input.reason || ""}`;
  if (!QUOTA_ERROR_TEXT.test(text)) return false;
  if (status === 401) return false;
  if (status === 403) return /quota|credit|usage[_\s-]*limit|exhausted/i.test(text);
  return true;
}

function drainQueue() {
  while (activeCount < MAX_CONCURRENT_REFRESHES && pending.size > 0) {
    const [connectionId, input] = pending.entries().next().value as [
      string,
      QuotaRefreshAfterProviderErrorInput,
    ];
    pending.delete(connectionId);
    activeCount++;

    void fetchAndPersistProviderLimits(connectionId, "error")
      .then(() => {
        const providerSuffix = input.provider ? ` (${input.provider})` : "";
        console.info(
          `[QuotaRefreshOnError] refreshed quota for ${connectionId.slice(0, 8)}${providerSuffix}`
        );
      })
      .catch((error) => {
        const message = error instanceof Error ? error.message : String(error);
        const providerSuffix = input.provider ? ` (${input.provider})` : "";
        console.debug(
          `[QuotaRefreshOnError] refresh skipped/failed for ${connectionId.slice(0, 8)}${providerSuffix}: ${message}`
        );
      })
      .finally(() => {
        activeCount--;
        drainQueue();
      });
  }
}

export function scheduleQuotaRefreshAfterProviderError(
  input: QuotaRefreshAfterProviderErrorInput
): boolean {
  const connectionId = typeof input.connectionId === "string" ? input.connectionId.trim() : "";
  if (!connectionId || !shouldRefreshForError(input)) return false;

  const now = Date.now();
  const last = lastScheduledAt.get(connectionId) || 0;
  if (now - last < THROTTLE_MS || pending.has(connectionId)) {
    return false;
  }

  lastScheduledAt.set(connectionId, now);
  pending.set(connectionId, { ...input, connectionId });
  const timer = setTimeout(drainQueue, 0);
  timer.unref?.();
  return true;
}

export function __resetQuotaRefreshOnErrorForTests() {
  lastScheduledAt.clear();
  pending.clear();
  activeCount = 0;
}
