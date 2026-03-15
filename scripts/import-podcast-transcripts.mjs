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

function extractHeaderValue(raw, label) {
  return sanitizeTitle(raw.match(new RegExp("^" + label + ":\\s*(.+)$", "mi"))?.[1] || "");
}

function toIsoDate(value) {
  if (!value) {
    return "";
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? value : parsed.toISOString();
}

function parseEpisodeNumber(title) {
  const match = String(title || "").match(/^(\d+)\b/);
  return match ? Number(match[1]) : null;
}

function parseSpeakers(body) {
  const speakers = [];
  const seen = new Set();
  const knownHosts = new Set(["McIntosh", "Kenshin"]);

  for (const line of String(body || "").split("\n")) {
    const speaker = line.match(/^\[[^\]]+\]\s+([^:]+):/)?.[1]?.trim();
    if (!speaker || seen.has(speaker)) {
      continue;
    }
    seen.add(speaker);
    speakers.push(speaker);
  }

  return {
    speakers,
    hosts: speakers.filter((speaker) => knownHosts.has(speaker)),
    guests: speakers.filter((speaker) => !knownHosts.has(speaker)),
  };
}

function parseNumber(value) {
  const cleaned = String(value || "").replace(/,/g, "");
  const parsed = Number(cleaned);
  return Number.isFinite(parsed) ? parsed : null;
}

function extractTranscriptMetadata(raw, body, fallbackTitle) {
  const title = extractHeaderValue(raw, "Title") || fallbackTitle;
  const publishedAt = toIsoDate(extractHeaderValue(raw, "Published"));
  const transcriptUrl = extractHeaderValue(raw, "Transcript URL");
  const episodeUrl = extractHeaderValue(raw, "Episode URL");
  const { speakers, hosts, guests } = parseSpeakers(body);

  const blockHeight =
    parseNumber(body.match(/block heights?[^0-9]{0,40}([0-9][0-9,]{4,})/i)?.[1]) ||
    parseNumber(body.match(/\b(9[0-9]{2},?[0-9]{3})\b/)?.[1]);

  const bitcoinPriceUsd =
    parseNumber(body.match(/our price[^0-9]{0,40}([0-9][0-9,]{3,}(?:\.\d+)?)/i)?.[1]) ||
    parseNumber(body.match(/price[^0-9]{0,20}([0-9][0-9,]{3,}(?:\.\d+)?)\s+US\b/i)?.[1]);

  const bitcoinPriceEur =
    parseNumber(body.match(/([0-9][0-9,]{3,}(?:\.\d+)?)\s+euros?\b/i)?.[1]) ||
    parseNumber(body.match(/price[^0-9]{0,20}([0-9][0-9,]{3,}(?:\.\d+)?)\s+EUR\b/i)?.[1]);

  const musicMatch =
    body.match(/This week's music.*?It's\s+(.+?)\s+by\s+(.+?)\./is) ||
    body.match(/music.*?is\s+(.+?)\s+by\s+(.+?)\./is);

  return {
    title,
    episodeNumber: parseEpisodeNumber(title),
    publishedAt,
    transcriptUrl,
    episodeUrl,
    speakers,
    hosts,
    guests,
    blockHeight,
    bitcoinPriceUsd,
    bitcoinPriceEur,
    musicTitle: musicMatch?.[1]?.trim() || "",
    musicArtist: musicMatch?.[2]?.trim() || "",
  };
}

function frontmatter({
  id,
  tenantId,
  title,
  sourceFile,
  episodeNumber,
  publishedAt,
  transcriptUrl,
  episodeUrl,
  speakers,
  hosts,
  guests,
  blockHeight,
  bitcoinPriceUsd,
  bitcoinPriceEur,
  musicTitle,
  musicArtist,
}) {
  const lines = [
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
  ];

  if (episodeNumber !== null) {
    lines.push(`episode_number: ${episodeNumber}`);
  }
  if (publishedAt) {
    lines.push(`published_at: ${JSON.stringify(publishedAt)}`);
  }
  if (episodeUrl) {
    lines.push(`episode_url: ${JSON.stringify(episodeUrl)}`);
  }
  if (transcriptUrl) {
    lines.push(`transcript_url: ${JSON.stringify(transcriptUrl)}`);
  }
  if (speakers.length > 0) {
    lines.push("speakers:");
    for (const speaker of speakers) {
      lines.push(`  - ${JSON.stringify(speaker)}`);
    }
  }
  if (hosts.length > 0) {
    lines.push("hosts:");
    for (const host of hosts) {
      lines.push(`  - ${JSON.stringify(host)}`);
    }
  }
  if (guests.length > 0) {
    lines.push("guests:");
    for (const guest of guests) {
      lines.push(`  - ${JSON.stringify(guest)}`);
    }
  }
  if (blockHeight !== null) {
    lines.push(`block_height: ${blockHeight}`);
  }
  if (bitcoinPriceUsd !== null) {
    lines.push(`bitcoin_price_usd: ${bitcoinPriceUsd}`);
  }
  if (bitcoinPriceEur !== null) {
    lines.push(`bitcoin_price_eur: ${bitcoinPriceEur}`);
  }
  if (musicTitle) {
    lines.push(`music_title: ${JSON.stringify(musicTitle)}`);
  }
  if (musicArtist) {
    lines.push(`music_artist: ${JSON.stringify(musicArtist)}`);
  }

  lines.push("---", "");
  return lines.join("\n");
}

function writeTranscriptChunk({
  outputDir,
  tenantId,
  baseId,
  metadata,
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
      title: `${metadata.title} (chunk ${chunkIndex})`,
      sourceFile,
      episodeNumber: metadata.episodeNumber,
      publishedAt: metadata.publishedAt,
      transcriptUrl: metadata.transcriptUrl,
      episodeUrl: metadata.episodeUrl,
      speakers: metadata.speakers,
      hosts: metadata.hosts,
      guests: metadata.guests,
      blockHeight: metadata.blockHeight,
      bitcoinPriceUsd: metadata.bitcoinPriceUsd,
      bitcoinPriceEur: metadata.bitcoinPriceEur,
      musicTitle: metadata.musicTitle,
      musicArtist: metadata.musicArtist,
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
    const fallbackTitle =
      sanitizeTitle(raw.match(/^Title:\s*(.+)$/m)?.[1] || "") ||
      deriveTitle(filePath, body);
    const metadata = extractTranscriptMetadata(raw, body, fallbackTitle);
    const baseId = slugify(path.basename(filePath, path.extname(filePath)));
    const chunks = chunkTranscript(body);
    for (let i = 0; i < chunks.length; i += 1) {
      const targetPath = writeTranscriptChunk({
        outputDir,
        tenantId,
        baseId,
        metadata,
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
    const link = sanitizeTitle(itemXml.match(/<link>([\s\S]*?)<\/link>/i)?.[1] || "");
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
      items.push({ title, pubDate, guid, link, transcripts });
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
      item.link ? `Episode URL: ${item.link}` : "",
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
