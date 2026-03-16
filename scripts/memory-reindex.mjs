#!/usr/bin/env node

import { execFileSync } from "node:child_process";

function usage() {
  console.error(
    [
      "usage:",
      "  memory-reindex.mjs <tenant-id> [--embed]",
    ].join("\n"),
  );
}

function main() {
  const [, , tenantId, ...args] = process.argv;
  if (!tenantId) {
    usage();
    process.exit(1);
  }

  const doEmbed = args.includes("--embed");
  const commandArgs = ["rebuild", tenantId];
  if (doEmbed) {
    commandArgs.push("--embed");
  }

  const output = execFileSync("clawbot-qmd-tenant", commandArgs, {
    encoding: "utf-8",
    stdio: ["ignore", "pipe", "pipe"],
  });

  process.stdout.write(output);
}

try {
  main();
} catch (error) {
  const detail = error instanceof Error ? error.message : String(error);
  console.error(detail);
  process.exit(1);
}
