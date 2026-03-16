#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

function usage() {
  console.error(
    [
      "usage:",
      "  observation-review.mjs list <tenant-id> [--bot <bot-id>] [--status <status>]",
      "  observation-review.mjs show <tenant-id> <observation-id>",
      "  observation-review.mjs reject <tenant-id> <observation-id>",
      "  observation-review.mjs promote <tenant-id> <observation-id>",
    ].join("\n"),
  );
}

function tenantRoot(tenantId) {
  return `/opt/clawbot/tenants/${tenantId}`;
}

function observationsRoot(tenantId) {
  return path.join(tenantRoot(tenantId), "memory", "observations");
}

function canonicalRoot(tenantId) {
  return path.join(tenantRoot(tenantId), "memory", "canonical");
}

function nowIso() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

function walkMarkdownFiles(rootDir) {
  const out = [];
  if (!fs.existsSync(rootDir)) {
    return out;
  }
  for (const entry of fs.readdirSync(rootDir, { withFileTypes: true })) {
    const target = path.join(rootDir, entry.name);
    if (entry.isDirectory()) {
      out.push(...walkMarkdownFiles(target));
      continue;
    }
    if (entry.isFile() && target.endsWith(".md")) {
      out.push(target);
    }
  }
  return out.sort();
}

function parseScalar(value) {
  const trimmed = String(value || "").trim();
  if ((trimmed.startsWith('"') && trimmed.endsWith('"')) || (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
    try {
      return JSON.parse(trimmed);
    } catch {
      return trimmed.slice(1, -1);
    }
  }
  return trimmed;
}

function parseFrontmatter(text) {
  const normalized = String(text || "").replace(/\r\n/g, "\n");
  if (!normalized.startsWith("---\n")) {
    return { meta: {}, body: normalized.trim() };
  }
  const end = normalized.indexOf("\n---\n", 4);
  if (end === -1) {
    return { meta: {}, body: normalized.trim() };
  }

  const block = normalized.slice(4, end);
  const body = normalized.slice(end + 5).replace(/^\n+/, "");
  const meta = {};
  let currentListKey = null;

  for (const line of block.split("\n")) {
    if (!line.trim()) {
      continue;
    }
    const listMatch = line.match(/^\s*-\s+(.*)$/);
    if (listMatch && currentListKey) {
      meta[currentListKey].push(parseScalar(listMatch[1]));
      continue;
    }
    const fieldMatch = line.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
    if (!fieldMatch) {
      currentListKey = null;
      continue;
    }
    const [, key, rawValue] = fieldMatch;
    if (rawValue === "") {
      meta[key] = [];
      currentListKey = key;
      continue;
    }
    meta[key] = parseScalar(rawValue);
    currentListKey = null;
  }

  return { meta, body: body.trim() };
}

function stringifyScalar(value) {
  return typeof value === "string" ? JSON.stringify(value) : String(value);
}

function stringifyFrontmatter(meta, body) {
  const lines = ["---"];
  for (const [key, value] of Object.entries(meta)) {
    if (value === undefined || value === null || value === "") {
      continue;
    }
    if (Array.isArray(value)) {
      lines.push(`${key}:`);
      for (const item of value) {
        lines.push(`  - ${stringifyScalar(item)}`);
      }
      continue;
    }
    lines.push(`${key}: ${stringifyScalar(value)}`);
  }
  lines.push("---", "", String(body || "").trim(), "");
  return lines.join("\n");
}

function loadObservationFile(filePath) {
  const text = fs.readFileSync(filePath, "utf8");
  const { meta, body } = parseFrontmatter(text);
  return { path: filePath, meta, body };
}

function allObservations(tenantId) {
  return walkMarkdownFiles(observationsRoot(tenantId)).map(loadObservationFile);
}

function findObservation(tenantId, observationId) {
  const match = allObservations(tenantId).find(
    (item) => String(item.meta.id || "") === observationId,
  );
  if (!match) {
    throw new Error(`observation not found: ${observationId}`);
  }
  return match;
}

function writeObservation(item) {
  fs.writeFileSync(item.path, stringifyFrontmatter(item.meta, item.body), "utf8");
}

function canonicalTargetForObservation(tenantId, item) {
  const botId = String(item.meta.bot_id || "").trim();
  if (!botId) {
    throw new Error(`observation ${item.meta.id || item.path} is missing bot_id`);
  }
  const canonicalId = String(item.meta.id || "")
    .replace(/^obs-/, "mem-")
    .trim();
  const targetDir = path.join(canonicalRoot(tenantId), "bots", botId);
  const targetPath = path.join(targetDir, `${canonicalId}.md`);
  return { canonicalId, targetDir, targetPath };
}

function writeCanonicalFromObservation(tenantId, item) {
  const { canonicalId, targetDir, targetPath } = canonicalTargetForObservation(tenantId, item);
  fs.mkdirSync(targetDir, { recursive: true });
  if (fs.existsSync(targetPath)) {
    throw new Error(`canonical memory already exists for observation ${item.meta.id}: ${targetPath}`);
  }

  const createdAt = String(item.meta.created_at || nowIso());
  const updatedAt = nowIso();
  const tags = Array.isArray(item.meta.tags) ? [...new Set([...item.meta.tags, "promoted-observation"])] : ["promoted-observation"];

  const canonicalMeta = {
    id: canonicalId,
    tenant_id: tenantId,
    scope: item.meta.scope || `tenant/${tenantId}/bot/${item.meta.bot_id}`,
    bot_id: item.meta.bot_id,
    type: "note",
    status: "active",
    visibility: item.meta.visibility || "bot",
    source: "observation_promotion",
    promoted_from: item.meta.id,
    created_at: createdAt,
    updated_at: updatedAt,
    tags,
  };

  fs.writeFileSync(targetPath, stringifyFrontmatter(canonicalMeta, item.body), "utf8");
  return { canonicalId, targetPath, updatedAt };
}

function commandList(tenantId, args) {
  let botId = "";
  let status = "";
  for (let i = 0; i < args.length; i += 1) {
    if (args[i] === "--bot") {
      botId = String(args[i + 1] || "").trim();
      i += 1;
      continue;
    }
    if (args[i] === "--status") {
      status = String(args[i + 1] || "").trim();
      i += 1;
    }
  }

  const observations = allObservations(tenantId)
    .filter((item) => !botId || String(item.meta.bot_id || "") === botId)
    .filter((item) => !status || String(item.meta.status || "") === status)
    .map((item) => ({
      id: item.meta.id || "",
      bot_id: item.meta.bot_id || "",
      status: item.meta.status || "",
      created_at: item.meta.created_at || "",
      updated_at: item.meta.updated_at || "",
      path: item.path,
      body_preview: item.body.split("\n")[0].slice(0, 160),
    }));

  console.log(JSON.stringify({ ok: true, tenantId, observations }, null, 2));
}

function commandShow(tenantId, observationId) {
  const item = findObservation(tenantId, observationId);
  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        observation: {
          path: item.path,
          meta: item.meta,
          body: item.body,
        },
      },
      null,
      2,
    ),
  );
}

function commandReject(tenantId, observationId) {
  const item = findObservation(tenantId, observationId);
  item.meta.status = "rejected";
  item.meta.updated_at = nowIso();
  writeObservation(item);
  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        observation: {
          id: item.meta.id,
          status: item.meta.status,
          path: item.path,
        },
      },
      null,
      2,
    ),
  );
}

function commandPromote(tenantId, observationId) {
  const item = findObservation(tenantId, observationId);
  const promotion = writeCanonicalFromObservation(tenantId, item);
  item.meta.status = "accepted";
  item.meta.updated_at = promotion.updatedAt;
  item.meta.promoted_to = promotion.canonicalId;
  item.meta.promoted_path = promotion.targetPath;
  writeObservation(item);
  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        observation: {
          id: item.meta.id,
          status: item.meta.status,
          path: item.path,
          promoted_to: promotion.canonicalId,
          promoted_path: promotion.targetPath,
        },
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

  if (command === "list") {
    const [tenantId, ...rest] = args;
    if (!tenantId) {
      usage();
      process.exit(1);
    }
    commandList(tenantId, rest);
    return;
  }

  if (command === "show") {
    const [tenantId, observationId] = args;
    if (!tenantId || !observationId) {
      usage();
      process.exit(1);
    }
    commandShow(tenantId, observationId);
    return;
  }

  if (command === "reject") {
    const [tenantId, observationId] = args;
    if (!tenantId || !observationId) {
      usage();
      process.exit(1);
    }
    commandReject(tenantId, observationId);
    return;
  }

  if (command === "promote") {
    const [tenantId, observationId] = args;
    if (!tenantId || !observationId) {
      usage();
      process.exit(1);
    }
    commandPromote(tenantId, observationId);
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
