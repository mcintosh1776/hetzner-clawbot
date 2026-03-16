#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const VALID_STATES = [
  "todo",
  "in_progress",
  "blocked",
  "ready_for_qa",
  "qa_failed",
  "qa_passed",
  "ready_for_approval",
  "done",
  "cancelled",
];

function usage() {
  console.error(
    [
      "usage:",
      "  clawbot-work-queue list <tenant-id> [--state <state>] [--owner <bot-id>]",
      "  clawbot-work-queue show <tenant-id> <task-id>",
      "  clawbot-work-queue create <tenant-id> <task-id> --title <title> --owner <bot-id> [--requested-by <actor>] [--priority <level>] [--category <kind>] [--state <state>]",
      "  clawbot-work-queue move <tenant-id> <task-id> <state> [--owner <bot-id>]",
      "  clawbot-work-queue handoff <tenant-id> <task-id> --to <bot-id> --status <state> --summary <text> [--from <bot-id>]",
    ].join("\n"),
  );
}

function nowIso() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

function tenantRoot(tenantId) {
  return path.join("/opt/clawbot/tenants", tenantId);
}

function queueRoot(tenantId) {
  return path.join(tenantRoot(tenantId), "work-queue");
}

function ensureQueueLayout(tenantId) {
  const root = queueRoot(tenantId);
  fs.mkdirSync(root, { recursive: true });
  for (const state of VALID_STATES) {
    fs.mkdirSync(path.join(root, state), { recursive: true });
  }
  return root;
}

function parseScalar(value) {
  const trimmed = String(value || "").trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    try {
      return JSON.parse(trimmed);
    } catch (_error) {
      return trimmed.slice(1, -1);
    }
  }
  if (trimmed === "true") {
    return true;
  }
  if (trimmed === "false") {
    return false;
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

  const meta = {};
  const block = normalized.slice(4, end);
  const body = normalized.slice(end + 5).replace(/^\n+/, "");
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
    const key = fieldMatch[1];
    const rawValue = fieldMatch[2];
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
  if (typeof value === "string") {
    return JSON.stringify(value);
  }
  if (typeof value === "boolean") {
    return value ? "true" : "false";
  }
  return String(value);
}

function stringifyFrontmatter(meta, body) {
  const lines = ["---"];
  for (const [key, value] of Object.entries(meta)) {
    if (value === undefined || value === null || value === "") {
      continue;
    }
    if (Array.isArray(value)) {
      lines.push(key + ":");
      for (const item of value) {
        lines.push("  - " + stringifyScalar(item));
      }
      continue;
    }
    lines.push(key + ": " + stringifyScalar(value));
  }
  lines.push("---", "", String(body || "").trim(), "");
  return lines.join("\n");
}

function taskPath(tenantId, state, taskId) {
  return path.join(queueRoot(tenantId), state, taskId + ".md");
}

function findTask(tenantId, taskId) {
  ensureQueueLayout(tenantId);
  for (const state of VALID_STATES) {
    const candidate = taskPath(tenantId, state, taskId);
    if (fs.existsSync(candidate)) {
      const text = fs.readFileSync(candidate, "utf8");
      const parsed = parseFrontmatter(text);
      return {
        path: candidate,
        state,
        meta: parsed.meta,
        body: parsed.body,
      };
    }
  }
  throw new Error("task not found: " + taskId);
}

function writeTask(filePath, meta, body) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, stringifyFrontmatter(meta, body), "utf8");
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

function parseArgs(args) {
  const out = {};
  for (let i = 0; i < args.length; i += 1) {
    const item = args[i];
    if (!item.startsWith("--")) {
      continue;
    }
    out[item.slice(2)] = String(args[i + 1] || "").trim();
    i += 1;
  }
  return out;
}

function defaultBody(title) {
  return [
    "## Objective",
    "",
    title,
    "",
    "## Constraints",
    "",
    "- TODO",
    "",
    "## Artifacts",
    "",
    "- TODO",
    "",
    "## Verify",
    "",
    "- TODO",
    "",
    "## Notes",
    "",
    "- TODO",
  ].join("\n");
}

function ensureValidState(state) {
  if (!VALID_STATES.includes(state)) {
    throw new Error("invalid state: " + state);
  }
}

function commandList(tenantId, args) {
  ensureQueueLayout(tenantId);
  const flags = parseArgs(args);
  const stateFilter = flags.state || "";
  const ownerFilter = flags.owner || "";
  if (stateFilter) {
    ensureValidState(stateFilter);
  }

  const tasks = walkMarkdownFiles(queueRoot(tenantId))
    .map((filePath) => {
      const text = fs.readFileSync(filePath, "utf8");
      const parsed = parseFrontmatter(text);
      return {
        task_id: parsed.meta.task_id || path.basename(filePath, ".md"),
        title: parsed.meta.title || "",
        status: parsed.meta.status || "",
        current_owner: parsed.meta.current_owner || "",
        priority: parsed.meta.priority || "",
        updated_at: parsed.meta.updated_at || "",
        path: filePath,
      };
    })
    .filter((task) => !stateFilter || task.status === stateFilter)
    .filter((task) => !ownerFilter || task.current_owner === ownerFilter);

  console.log(JSON.stringify({ ok: true, tenantId, tasks }, null, 2));
}

function commandShow(tenantId, taskId) {
  const task = findTask(tenantId, taskId);
  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        task: {
          path: task.path,
          state: task.state,
          meta: task.meta,
          body: task.body,
        },
      },
      null,
      2,
    ),
  );
}

function commandCreate(tenantId, taskId, args) {
  ensureQueueLayout(tenantId);
  const flags = parseArgs(args);
  const title = flags.title || "";
  const owner = flags.owner || "";
  if (!title || !owner) {
    throw new Error("create requires --title and --owner");
  }
  const state = flags.state || "todo";
  ensureValidState(state);
  const target = taskPath(tenantId, state, taskId);
  if (fs.existsSync(target)) {
    throw new Error("task already exists: " + taskId);
  }

  const timestamp = nowIso();
  const meta = {
    task_id: taskId,
    tenant_id: tenantId,
    title,
    requested_by: flags["requested-by"] || "operator",
    current_owner: owner,
    status: state,
    priority: flags.priority || "medium",
    created_at: timestamp,
    updated_at: timestamp,
    category: flags.category || "general",
    requires_operator_approval: false,
  };

  writeTask(target, meta, defaultBody(title));
  console.log(JSON.stringify({ ok: true, tenantId, task_id: taskId, path: target }, null, 2));
}

function commandMove(tenantId, taskId, state, args) {
  ensureValidState(state);
  const flags = parseArgs(args);
  const task = findTask(tenantId, taskId);
  const nextOwner = flags.owner || String(task.meta.current_owner || "");
  task.meta.status = state;
  task.meta.current_owner = nextOwner;
  task.meta.updated_at = nowIso();
  const target = taskPath(tenantId, state, taskId);
  if (target !== task.path) {
    fs.rmSync(task.path, { force: true });
  }
  writeTask(target, task.meta, task.body);
  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        task_id: taskId,
        status: state,
        current_owner: nextOwner,
        path: target,
      },
      null,
      2,
    ),
  );
}

function appendLatestHandoff(body, handoff) {
  const lines = [
    String(body || "").trim(),
    "",
    "## Latest handoff",
    "",
    "- from: " + handoff.from,
    "- to: " + handoff.to,
    "- at: " + handoff.at,
    "- summary: " + handoff.summary,
    "- status: " + handoff.status,
  ];
  return lines.join("\n").trim() + "\n";
}

function commandHandoff(tenantId, taskId, args) {
  const flags = parseArgs(args);
  const to = flags.to || "";
  const status = flags.status || "";
  const summary = flags.summary || "";
  if (!to || !status || !summary) {
    throw new Error("handoff requires --to, --status, and --summary");
  }
  ensureValidState(status);
  const task = findTask(tenantId, taskId);
  const from = flags.from || String(task.meta.current_owner || "");
  const timestamp = nowIso();
  task.meta.current_owner = to;
  task.meta.status = status;
  task.meta.updated_at = timestamp;
  task.body = appendLatestHandoff(task.body, {
    from,
    to,
    at: timestamp,
    summary,
    status,
  });
  const target = taskPath(tenantId, status, taskId);
  if (target !== task.path) {
    fs.rmSync(task.path, { force: true });
  }
  writeTask(target, task.meta, task.body);
  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        task_id: taskId,
        from,
        to,
        status,
        path: target,
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
    const tenantId = args[0];
    if (!tenantId) {
      usage();
      process.exit(1);
    }
    commandList(tenantId, args.slice(1));
    return;
  }

  if (command === "show") {
    const tenantId = args[0];
    const taskId = args[1];
    if (!tenantId || !taskId) {
      usage();
      process.exit(1);
    }
    commandShow(tenantId, taskId);
    return;
  }

  if (command === "create") {
    const tenantId = args[0];
    const taskId = args[1];
    if (!tenantId || !taskId) {
      usage();
      process.exit(1);
    }
    commandCreate(tenantId, taskId, args.slice(2));
    return;
  }

  if (command === "move") {
    const tenantId = args[0];
    const taskId = args[1];
    const state = args[2];
    if (!tenantId || !taskId || !state) {
      usage();
      process.exit(1);
    }
    commandMove(tenantId, taskId, state, args.slice(3));
    return;
  }

  if (command === "handoff") {
    const tenantId = args[0];
    const taskId = args[1];
    if (!tenantId || !taskId) {
      usage();
      process.exit(1);
    }
    commandHandoff(tenantId, taskId, args.slice(2));
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
