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

function canonicalCollections(tenantId) {
  const root = canonicalRoot(tenantId);
  const collections = [];

  const sharedDir = path.join(root, "shared");
  if (fs.existsSync(sharedDir)) {
    collections.push({ name: "shared", dir: sharedDir });
  }

  const botsDir = path.join(root, "bots");
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

  return collections.sort((a, b) => a.name.localeCompare(b.name));
}

function knownBotIdsForTenant(tenantId) {
  return canonicalCollections(tenantId)
    .filter((collection) => collection.name.startsWith("bot-"))
    .map((collection) => collection.name.replace(/^bot-/, ""));
}

function allowedCollectionsForBot(tenantId, botId) {
  const known = new Set(knownBotIdsForTenant(tenantId));
  if (!known.has(botId)) {
    throw new Error(`unknown bot id for tenant ${tenantId}: ${botId}`);
  }
  return ["shared", `bot-${botId}`];
}

function ensureCollections(tenantId) {
  const collections = canonicalCollections(tenantId);
  if (collections.length === 0) {
    throw new Error(`no canonical collections found for tenant ${tenantId}`);
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

  return collections;
}

function parseJsonOrText(output) {
  try {
    return JSON.parse(output);
  } catch {
    return output.trim();
  }
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
  const args = ["query", queryText, "--json", "--limit", "5"];

  for (const collection of allowedCollections) {
    args.push("--collection", collection);
  }

  const results = parseJsonOrText(runQmd(tenantId, args));
  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        botId,
        query: queryText,
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
