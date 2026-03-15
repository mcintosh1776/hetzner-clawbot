#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import os from "node:os";

function usage() {
  console.error(
    [
      "usage:",
      "  import-podcast-transcripts.mjs import-dir <tenant-id> <input-dir>",
      "  import-podcast-transcripts.mjs fetch-feed <tenant-id> [feed-url] [--limit N]",
    ].join("\n"),
  );
}

function tenantTranscriptRoot(tenantId) {
  return `/opt/clawbot/tenants/${tenantId}/memory/sources/transcripts`;
}

const DEFAULT_FEED_URL =
  process.env.CLAWBOT_PODCAST_RSS_FEED ||
  "https://serve.podhome.fm/rss/3d1d205b-b9f7-5253-b09d-df1c8ec4fc25";

function slugify(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80) || "transcript";
}

function normalizeTranscriptBody(raw) {
  const text = String(raw || "").replace(/\r\n/g, "\n");
  if (/<(?:cite|time|p)\b/i.test(text)) {
    return normalizePodcastHtmlTranscript(text);
  }

  const lines = text.split("\n").map((line) => line.trimEnd());

  const out = [];
  let previousBlank = false;

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) {
      if (!previousBlank) {
        out.push("");
      }
      previousBlank = true;
      continue;
    }
    previousBlank = false;
    out.push(trimmed);
  }

  return out.join("\n").trim() + "\n";
}

function normalizePodcastHtmlTranscript(raw) {
  const lines = [];
  let currentSpeaker = "";
  let currentTime = "";
  const tokenRegex = /<cite>([\s\S]*?)<\/cite>|<time>([\s\S]*?)<\/time>|<p>([\s\S]*?)<\/p>/gi;

  for (const match of String(raw || "").matchAll(tokenRegex)) {
    if (match[1] !== undefined) {
      currentSpeaker = decodeXml(match[1]).replace(/:\s*$/, "").trim();
      continue;
    }

    if (match[2] !== undefined) {
      currentTime = decodeXml(match[2]).trim();
      continue;
    }

    if (match[3] !== undefined) {
      const text = decodeXml(match[3])
        .replace(/<[^>]+>/g, " ")
        .replace(/\s+/g, " ")
        .trim();
      if (!text) {
        continue;
      }
      const prefix = currentTime ? `[${currentTime}] ` : "";
      const speaker = currentSpeaker ? `${currentSpeaker}: ` : "";
      lines.push(`${prefix}${speaker}${text}`.trim());
    }
  }

  return lines.join("\n").trim() + "\n";
}

function deriveTitle(filePath, body) {
  const firstLine = body.split("\n").find((line) => line.trim());
  if (firstLine && firstLine.length <= 120) {
    return firstLine.replace(/^\[[^\]]+\]\s*/, "").slice(0, 120);
  }
  return path.basename(filePath, path.extname(filePath));
}

function frontmatter({ id, tenantId, title, sourceFile }) {
  return [
    "---",
    `id: ${id}`,
    `tenant_id: ${tenantId}`,
    "scope: tenant/" + tenantId + "/source/transcripts",
    "type: transcript",
    "status: active",
    "visibility: bot",
    "source: transcript_import",
    "tags:",
    "  - transcript",
    "  - podcast",
    `title: ${JSON.stringify(title)}`,
    `source_file: ${JSON.stringify(sourceFile)}`,
    "---",
    "",
  ].join("\n");
}

function writeTranscriptChunk({
  outputDir,
  tenantId,
  baseId,
  title,
  sourceFile,
  chunkIndex,
  lines,
}) {
  if (!lines.length) {
    return null;
  }
  const id = `${baseId}-chunk-${String(chunkIndex).padStart(3, "0")}`;
  const targetPath = path.join(outputDir, `${id}.md`);
  fs.writeFileSync(
    targetPath,
    frontmatter({
      id,
      tenantId,
      title: `${title} (chunk ${chunkIndex})`,
      sourceFile,
    }) + lines.join("\n").trim() + "\n",
    "utf8",
  );
  return targetPath;
}

function chunkTranscript(body) {
  const lines = body
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
  const chunks = [];
  let current = [];

  for (const line of lines) {
    current.push(line);
    if (current.length >= 80) {
      chunks.push(current);
      current = [];
    }
  }

  if (current.length > 0) {
    chunks.push(current);
  }

  return chunks;
}

function importDir(tenantId, inputDir) {
  const outputDir = tenantTranscriptRoot(tenantId);
  fs.mkdirSync(outputDir, { recursive: true });

  const files = fs
    .readdirSync(inputDir, { withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => path.join(inputDir, entry.name))
    .filter((filePath) => /\.(txt|md)$/i.test(filePath))
    .sort();

  const imported = [];

  for (const filePath of files) {
    const raw = fs.readFileSync(filePath, "utf8");
    const body = normalizeTranscriptBody(raw);
    const title =
      sanitizeTitle(raw.match(/^Title:\s*(.+)$/m)?.[1] || "") ||
      deriveTitle(filePath, body);
    const baseId = slugify(path.basename(filePath, path.extname(filePath)));
    const chunks = chunkTranscript(body);
    for (let i = 0; i < chunks.length; i += 1) {
      const targetPath = writeTranscriptChunk({
        outputDir,
        tenantId,
        baseId,
        title,
        sourceFile: path.basename(filePath),
        chunkIndex: i + 1,
        lines: chunks[i],
      });
      if (targetPath) {
        imported.push(targetPath);
      }
    }
  }

  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        inputDir,
        outputDir,
        imported,
      },
      null,
      2,
    ),
  );
}

function decodeXml(value) {
  return String(value || "")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function sanitizeTitle(value) {
  return decodeXml(String(value || "").replace(/<!\[CDATA\[|\]\]>/g, "")).trim();
}

function parseFeed(feedXml) {
  const items = [];
  const itemRegex = /<item\b[\s\S]*?<\/item>/gi;
  const transcriptRegex = /<(?:podcast:)?transcript\b([^>]*)\/?>/gi;

  for (const itemMatch of String(feedXml || "").matchAll(itemRegex)) {
    const itemXml = itemMatch[0];
    const title = sanitizeTitle(itemXml.match(/<title>([\s\S]*?)<\/title>/i)?.[1] || "");
    const pubDate = sanitizeTitle(itemXml.match(/<pubDate>([\s\S]*?)<\/pubDate>/i)?.[1] || "");
    const guid = sanitizeTitle(itemXml.match(/<guid[^>]*>([\s\S]*?)<\/guid>/i)?.[1] || "");
    const transcripts = [];

    for (const transcriptMatch of itemXml.matchAll(transcriptRegex)) {
      const attrs = transcriptMatch[1] || "";
      const url = attrs.match(/\burl="([^"]+)"/i)?.[1] || attrs.match(/\burl='([^']+)'/i)?.[1] || "";
      const type = attrs.match(/\btype="([^"]+)"/i)?.[1] || attrs.match(/\btype='([^']+)'/i)?.[1] || "";
      const language = attrs.match(/\blanguage="([^"]+)"/i)?.[1] || attrs.match(/\blanguage='([^']+)'/i)?.[1] || "";
      if (url) {
        transcripts.push({ url: decodeXml(url), type: decodeXml(type), language: decodeXml(language) });
      }
    }

    if (transcripts.length > 0) {
      items.push({ title, pubDate, guid, transcripts });
    }
  }

  return items;
}

async function fetchText(url) {
  const response = await fetch(url, {
    headers: {
      "User-Agent": "clawbot-transcript-import/1.0",
      "Accept": "application/rss+xml, application/xml, text/plain, text/vtt, */*",
    },
  });
  if (!response.ok) {
    throw new Error(`fetch failed for ${url}: ${response.status} ${response.statusText}`);
  }
  return await response.text();
}

async function commandFetchFeed(tenantId, feedUrl, limit) {
  const xml = await fetchText(feedUrl);
  const items = parseFeed(xml);
  const selected = items.slice(0, limit > 0 ? limit : items.length);
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), `clawbot-transcripts-${tenantId}-`));

  for (let index = 0; index < selected.length; index += 1) {
    const item = selected[index];
    const transcript = item.transcripts.find((entry) => !entry.language || entry.language.toLowerCase().startsWith("en")) || item.transcripts[0];
    const rawText = await fetchText(transcript.url);
    const fileBase = slugify(item.guid || item.title || `episode-${index + 1}`);
    const sourcePath = path.join(tempDir, `${fileBase}.txt`);
    const header = [
      item.title ? `Title: ${item.title}` : "",
      item.pubDate ? `Published: ${item.pubDate}` : "",
      transcript.url ? `Transcript URL: ${transcript.url}` : "",
      "",
    ]
      .filter(Boolean)
      .join("\n");
    fs.writeFileSync(sourcePath, `${header}${rawText}`, "utf8");
  }

  importDir(tenantId, tempDir);
}

const [, , command, tenantId, ...rest] = process.argv;

if (!tenantId) {
  usage();
  process.exit(1);
}

if (command === "import-dir") {
  const [inputDir] = rest;
  if (!inputDir) {
    usage();
    process.exit(1);
  }
  importDir(tenantId, inputDir);
  process.exit(0);
}

if (command === "fetch-feed") {
  let feedUrl = DEFAULT_FEED_URL;
  let limit = 25;

  for (let i = 0; i < rest.length; i += 1) {
    const arg = rest[i];
    if (arg === "--limit") {
      limit = Number(rest[i + 1] || "25");
      i += 1;
      continue;
    }
    if (!arg.startsWith("--")) {
      feedUrl = arg;
    }
  }

  await commandFetchFeed(tenantId, feedUrl, limit);
  process.exit(0);
}

usage();
process.exit(1);
