// Aperture's /v1/models is the per-user catalog, limits included. OpenCode's
// built-in discovery only covers local servers, so project the Chat
// Completions models into one provider at startup.
//
// Plain .js, node builtins only, so opencode loads it without a package.json /
// bun install. Auto-discovered from ~/.config/opencode/plugin/.
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

const origin = process.env.APERTURE_URL || "http://ai.corp.ts.net";
const providerID = "aperture-openai-compatible";
const cache = join(
  process.env.XDG_CACHE_HOME || join(homedir(), ".cache"),
  "opencode-aperture",
  "models.json",
);

const positive = (n) => (Number.isSafeInteger(n) && n > 0 ? n : undefined);

// Throws on an unusable page so it never replaces the cached one.
function chatModels(page) {
  if (!Array.isArray(page?.data)) throw new Error("no model list");
  const models = new Map();
  for (const m of page.data) {
    const endpoints = Array.isArray(m?.supported_endpoints) ? m.supported_endpoints : [];
    // One id can be listed once per backing route; requests route by id alone.
    if (typeof m?.id === "string" && endpoints.includes("/v1/chat/completions") && !models.has(m.id))
      models.set(m.id, m);
  }
  if (models.size === 0) throw new Error("no chat models");
  return [...models.values()];
}

async function load() {
  try {
    const response = await fetch(`${origin}/v1/models`, { signal: AbortSignal.timeout(5_000) });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const page = await response.json();
    const models = chatModels(page);
    const temporary = `${cache}.${process.pid}`;
    await mkdir(dirname(cache), { recursive: true })
      .then(() => writeFile(temporary, JSON.stringify(page)))
      .then(() => rename(temporary, cache))
      .catch(() => {});
    return models;
  } catch (error) {
    // Keep the last good catalog through Aperture outages.
    try {
      return chatModels(JSON.parse(await readFile(cache, "utf8")));
    } catch {
      console.error(`aperture-models: ${error.message}, and no cached catalog`);
      return [];
    }
  }
}

export default {
  id: "aperture-models",
  async setup(ctx) {
    // ponytail: fetched once per process; restart opencode to pick up new models.
    const models = await load();
    if (models.length === 0) return;
    await ctx.provider.transform((providers) => {
      providers.update(providerID, (provider) => {
        provider.name = "Aperture";
        provider.activation = "enabled";
        provider.package = "@opencode/ai/providers/openai-compatible";
        provider.settings = { baseURL: `${origin}/v1`, provider: providerID, apiKey: "not-required" };
      });
      for (const m of models) {
        providers.models.update(providerID, m.id, (model) => {
          model.name = m.display_name || m.id;
          model.limit.context = positive(m.context_window_tokens) ?? model.limit.context;
          model.limit.output = positive(m.max_output_tokens) ?? model.limit.output;
        });
      }
    });
  },
};
