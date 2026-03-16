#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

function usage() {
  console.error(
    [
      "usage:",
      "  qmd-tenant-wrapper.mjs status <tenant-id>",
      "  qmd-tenant-wrapper.mjs rebuild <tenant-id> [--embed]",
      "  qmd-tenant-wrapper.mjs query <tenant-id> <bot-id> <query...>",
    ].join("\n"),
  );
}

function tenantRoot(tenantId) {
  return `/opt/clawbot/tenants/${tenantId}`;
}

function canonicalRoot(tenantId) {
  return path.join(tenantRoot(tenantId), "memory", "canonical");
}

function sourcesRoot(tenantId) {
  return path.join(tenantRoot(tenantId), "memory", "sources");
}

function retrievalRoot(tenantId) {
  return path.join(tenantRoot(tenantId), "memory", "retrieval", "qmd");
}

function qmdHome(tenantId) {
  return path.join(retrievalRoot(tenantId), "home");
}

function qmdEnv(tenantId) {
  const home = qmdHome(tenantId);
  return {
    ...process.env,
    HOME: home,
    XDG_CONFIG_HOME: path.join(home, ".config"),
    XDG_CACHE_HOME: path.join(home, ".cache"),
    XDG_DATA_HOME: path.join(home, ".local", "share"),
  };
}

function ensureQmdDirs(tenantId) {
  for (const dir of [
    retrievalRoot(tenantId),
    qmdHome(tenantId),
    path.join(qmdHome(tenantId), ".config"),
    path.join(qmdHome(tenantId), ".cache"),
    path.join(qmdHome(tenantId), ".local", "share"),
  ]) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function runQmd(tenantId, args, options = {}) {
  ensureQmdDirs(tenantId);
  return execFileSync("qmd", args, {
    encoding: "utf-8",
    stdio: ["ignore", "pipe", "pipe"],
    env: qmdEnv(tenantId),
    ...options,
  });
}

function tenantCollections(tenantId) {
  const collections = [];

  const sharedDir = path.join(canonicalRoot(tenantId), "shared");
  if (fs.existsSync(sharedDir)) {
    collections.push({ name: "shared", dir: sharedDir });
  }

  const botsDir = path.join(canonicalRoot(tenantId), "bots");
  if (fs.existsSync(botsDir)) {
    for (const entry of fs.readdirSync(botsDir, { withFileTypes: true })) {
      if (!entry.isDirectory()) {
        continue;
      }
      collections.push({
        name: `bot-${entry.name}`,
        dir: path.join(botsDir, entry.name),
      });
    }
  }

  const transcriptDir = path.join(sourcesRoot(tenantId), "transcripts");
  if (fs.existsSync(transcriptDir)) {
    collections.push({ name: "source-transcripts", dir: transcriptDir });
  }

  return collections.sort((a, b) => a.name.localeCompare(b.name));
}

function knownBotIdsForTenant(tenantId) {
  return tenantCollections(tenantId)
    .filter((collection) => collection.name.startsWith("bot-"))
    .map((collection) => collection.name.replace(/^bot-/, ""));
}

function allowedCollectionsForBot(tenantId, botId) {
  const known = new Set(knownBotIdsForTenant(tenantId));
  if (!known.has(botId)) {
    throw new Error(`unknown bot id for tenant ${tenantId}: ${botId}`);
  }
  const allowed = ["shared", `bot-${botId}`];
  const collections = new Set(tenantCollections(tenantId).map((collection) => collection.name));
  if (botId === "steve" && collections.has("source-transcripts")) {
    allowed.push("source-transcripts");
  }
  return allowed;
}

function desiredContextsForTenant(tenantId) {
  const contexts = {
    shared:
      "Shared tenant_0 brand voice and cross-fleet operating guidance. Bitcoin-first, credible, human, anti-hype, and useful for all tenant_0 bots.",
    "source-transcripts":
      "Tenant_0 podcast transcript corpus. Retrieval source material from normalized episode transcripts; useful for Steve when recalling what was said in past episodes.",
  };

  for (const botId of knownBotIdsForTenant(tenantId)) {
    const collectionName = `bot-${botId}`;
    const defaults = {
      bob: "Bob coordination memory. Boundaries, routing, escalation, cross-bot authority limits, and coordinator behavior for tenant_0.",
      stacks:
        "Stacks media and social tone memory. Warmer friendlier tone, approachable Bitcoin-first media voice, avoid robotic copy and hype.",
      jennifer:
        "Jennifer editorial and research memory. Editorial discipline, evidence-minded framing, calm authority, and avoid marketing tone.",
      steve:
        "Steve engineering memory. Pragmatic implementation, small reviewable changes, migration safety, and avoid unnecessary rewrites.",
      number5:
        "Number5 business and operations memory. Business framing, operational thinking, structured proposals, and clear assumptions.",
    };
    contexts[collectionName] =
      defaults[botId] || `${botId} bot-private tenant_0 memory for role guidance and durable preferences.`;
  }

  return contexts;
}

function ensureCollectionContexts(tenantId, collections) {
  const contexts = desiredContextsForTenant(tenantId);

  for (const collection of collections) {
    const target = `qmd://${collection.name}/`;
    const summary = contexts[collection.name];
    if (!summary) {
      continue;
    }

    try {
      runQmd(tenantId, ["context", "add", target, summary]);
    } catch (error) {
      const stderr = String(error?.stderr || "");
      if (!/already exists|already has context|duplicate/i.test(stderr)) {
        throw new Error(
          `failed to add qmd context for ${collection.name}: ${stderr || error.message}`,
        );
      }
    }
  }
}

function ensureCollections(tenantId) {
  const collections = tenantCollections(tenantId);
  if (collections.length === 0) {
    throw new Error(`no memory collections found for tenant ${tenantId}`);
  }

  for (const collection of collections) {
    try {
      runQmd(tenantId, ["collection", "add", collection.dir, "--name", collection.name]);
    } catch (error) {
      const stderr = error?.stderr || "";
      if (!/already exists/i.test(stderr)) {
        throw new Error(
          `failed to register qmd collection ${collection.name}: ${stderr || error.message}`,
        );
      }
    }
  }

  ensureCollectionContexts(tenantId, collections);
  return collections;
}

function parseJsonOrText(output) {
  try {
    return JSON.parse(output);
  } catch {
    return output.trim();
  }
}

function uniqueQueries(queryText) {
  const variants = [];
  const seen = new Set();

  function addVariant(value) {
    const normalized = String(value || "").trim().replace(/\s+/g, " ");
    if (!normalized || seen.has(normalized)) {
      return;
    }
    seen.add(normalized);
    variants.push(normalized);
  }

  addVariant(queryText);
  addVariant(String(queryText || "").replace(/(?<=\d),(?=\d)/g, ""));

  const millionVariant = String(queryText || "").replace(
    /\b(\d{1,3})(?:,\d{3}){2}\b/g,
    (_match, millions) => `${Number(millions)} million`,
  );
  addVariant(millionVariant);

  return variants;
}

function mergeResultsByDoc(queries, resultsByQuery) {
  const merged = [];
  const seen = new Set();

  for (const query of queries) {
    for (const item of resultsByQuery.get(query) || []) {
      const key = `${item.docid || ""}|${item.file || ""}`;
      if (seen.has(key)) {
        continue;
      }
      seen.add(key);
      merged.push(item);
    }
  }

  return merged;
}

function commandStatus(tenantId) {
  const collections = ensureCollections(tenantId);
  const output = runQmd(tenantId, ["status", "--json"]);
  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        retrievalRoot: retrievalRoot(tenantId),
        collections: collections.map((collection) => collection.name),
        status: parseJsonOrText(output),
      },
      null,
      2,
    ),
  );
}

function commandRebuild(tenantId, args) {
  const doEmbed = args.includes("--embed");
  const collections = ensureCollections(tenantId);
  const update = parseJsonOrText(runQmd(tenantId, ["update", "--json"]));
  const embed = doEmbed ? parseJsonOrText(runQmd(tenantId, ["embed", "--json"])) : null;

  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        retrievalRoot: retrievalRoot(tenantId),
        collections: collections.map((collection) => collection.name),
        update,
        embed,
      },
      null,
      2,
    ),
  );
}

function commandQuery(tenantId, botId, queryText) {
  ensureCollections(tenantId);
  const allowedCollections = allowedCollectionsForBot(tenantId, botId);
  const queryVariants = uniqueQueries(queryText);
  const resultsByQuery = new Map();

  for (const queryVariant of queryVariants) {
    const args = ["search", queryVariant, "--json", "-n", "5"];
    for (const collection of allowedCollections) {
      args.push("-c", collection);
    }
    const parsed = parseJsonOrText(runQmd(tenantId, args));
    resultsByQuery.set(queryVariant, Array.isArray(parsed) ? parsed : []);
  }

  const results = mergeResultsByDoc(queryVariants, resultsByQuery);
  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        botId,
        query: queryText,
        queryVariants,
        allowedCollections,
        retrievalRoot: retrievalRoot(tenantId),
        results,
      },
      null,
      2,
    ),
  );
}

function main() {
  const [, , command, ...args] = process.argv;

  if (!command) {
    usage();
    process.exit(1);
  }

  if (command === "status") {
    const [tenantId] = args;
    if (!tenantId) {
      usage();
      process.exit(1);
    }
    commandStatus(tenantId);
    return;
  }

  if (command === "rebuild") {
    const [tenantId, ...rest] = args;
    if (!tenantId) {
      usage();
      process.exit(1);
    }
    commandRebuild(tenantId, rest);
    return;
  }

  if (command === "query") {
    const [tenantId, botId, ...queryParts] = args;
    if (!tenantId || !botId || queryParts.length === 0) {
      usage();
      process.exit(1);
    }
    commandQuery(tenantId, botId, queryParts.join(" "));
    return;
  }

  usage();
  process.exit(1);
}

try {
  main();
} catch (error) {
  const detail = error instanceof Error ? error.message : String(error);
  console.error(detail);
  process.exit(1);
}
