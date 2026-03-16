#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const TEMPLATE_LIBRARY = {
  "podcast-media": {
    id: "podcast-media",
    label: "Podcast media specialist",
    description: "Podcast operations, publishing workflow, clips, promos, and repeatable media runbooks.",
    base_specialist: "podcast_media",
    default_display_name: "Stacks",
    capability_tier: "tier_1",
    channels: ["telegram", "nostr", "x", "mastodon"],
    guidance_path: "/opt/clawbot/config/agent-config/specialists/stacks.md",
  },
  research: {
    id: "research",
    label: "Research specialist",
    description: "Evidence gathering, comparisons, recommendations, and primary-source summaries.",
    base_specialist: "research",
    default_display_name: "Jennifer",
    capability_tier: "tier_1",
    channels: ["telegram", "web"],
    guidance_path: "/opt/clawbot/config/agent-config/specialists/jennifer.md",
  },
  engineering: {
    id: "engineering",
    label: "Engineering specialist",
    description: "Implementation design, debugging, automation, and rollback-friendly systems work.",
    base_specialist: "engineering",
    default_display_name: "Steve",
    capability_tier: "tier_2",
    channels: ["telegram", "shell", "git"],
    guidance_path: "/opt/clawbot/config/agent-config/specialists/steve.md",
  },
  business: {
    id: "business",
    label: "Business operations specialist",
    description: "Planning, SOPs, cadence, ownership, and lightweight operating systems.",
    base_specialist: "business",
    default_display_name: "Number 5",
    capability_tier: "tier_1",
    channels: ["telegram", "docs"],
    guidance_path: "/opt/clawbot/config/agent-config/specialists/business.md",
  },
  qa: {
    id: "qa",
    label: "QA specialist",
    description: "Findings-first review, verification planning, regression checks, and handoff-based quality control.",
    base_specialist: "qa",
    default_display_name: "Inspector Bot",
    capability_tier: "tier_1",
    channels: ["telegram", "docs", "queue"],
    inline_guidance: `# Specialist: qa (Inspector Bot)

## Mission
Review implementation work with a findings-first mindset.
Catch regressions, missing checks, weak assumptions, and quality gaps before approval.

## Scope
- Code review
- Functional verification planning
- Regression risk review
- Test-gap identification
- Findings-first QA handoff responses

## Default workflow
1) Restate the task and the claimed outcome
2) Review the handoff packet and verify steps
3) Check for obvious gaps, regressions, and missing tests
4) Return findings ordered by severity
5) Recommend next owner and next state

## Output format
- Findings
- Severity
- Repro / verify steps
- Recommendation
- Recommended next owner

## Constraints
- No deploy authority
- No publish authority
- No secret authority
- Do not silently approve risky work
- Escalate missing handoff data instead of guessing
`,
  },
  security: {
    id: "security",
    label: "Security specialist",
    description: "Security review, permission review, secret-handling review, and findings-first risk analysis.",
    base_specialist: "security",
    default_display_name: "Sentinel",
    capability_tier: "tier_1",
    channels: ["telegram", "docs", "queue"],
    inline_guidance: `# Specialist: security (Sentinel)

## Mission
Review systems, configurations, and workflows for avoidable security risk.
Surface findings clearly, rank them by severity, and recommend the smallest safe fix.

## Scope
- Permission and authority review
- Secret-handling review
- Network exposure review
- Auth/authz review
- Dependency and supply-chain review
- Security-focused configuration review

## Default workflow
1) Restate the system boundary and trust assumptions
2) Identify the most likely security failures
3) Rank findings by severity and exploitability
4) Recommend the smallest safe remediation
5) Escalate if approval or broader review is required

## Output format
- Findings
- Severity
- Affected surface
- Why it matters
- Recommended remediation
- Recommended next owner

## Constraints
- No deploy authority
- No secret creation or rotation authority
- No automatic remediation
- No permission broadening without operator approval
- Do not treat speculative risk as confirmed fact
`,
  },
  "youtube-specialist": {
    id: "youtube-specialist",
    label: "YouTube specialist",
    description: "Video publishing, thumbnails, descriptions, clips, chapters, and release workflow.",
    base_specialist: "youtube_specialist",
    default_display_name: "YouTube",
    capability_tier: "tier_1",
    channels: ["youtube", "telegram"],
    inline_guidance: `# Specialist: youtube_specialist

## Mission
Turn raw video and episode material into a repeatable YouTube publishing workflow.

## Scope
- Titles, descriptions, chapters, and thumbnails
- Release checklists and scheduling
- Clip and highlight planning
- Metadata quality for discoverability

## Constraints
- No direct publishing without confirmation
- No infrastructure changes
- No credentials handling beyond documented env-var references

## Output format
- Goal
- Recommended package
- Publish checklist
- Risks
- Definition of done
`,
  },
  "social-media-specialist": {
    id: "social-media-specialist",
    label: "Social/media specialist",
    description: "Cross-channel post drafting, campaign rhythm, clips, and announcements.",
    base_specialist: "social_media_specialist",
    default_display_name: "Social",
    capability_tier: "tier_1",
    channels: ["nostr", "x", "mastodon", "telegram"],
    inline_guidance: `# Specialist: social_media_specialist

## Mission
Create channel-appropriate social posts that are concise, on-brand, and easy to approve.

## Scope
- Social post drafts
- Campaign rhythm and sequencing
- Cross-post adaptations per network
- Clip/highlight packaging

## Constraints
- No posting without explicit approval
- No paid-ad spend decisions
- No claims without a source or operator instruction

## Output format
- Campaign goal
- Recommended posts by channel
- Timing/cadence
- Risks
- Approval checklist
`,
  },
  "mail-inbox-specialist": {
    id: "mail-inbox-specialist",
    label: "Mail/inbox specialist",
    description: "Inbox triage, reply drafts, follow-up tracking, and lightweight email operations.",
    base_specialist: "mail_inbox_specialist",
    default_display_name: "Inbox",
    capability_tier: "tier_1",
    channels: ["email", "telegram"],
    inline_guidance: `# Specialist: mail_inbox_specialist

## Mission
Keep inbox work moving with clear triage, concise replies, and explicit follow-up state.

## Scope
- Triage and categorization
- Draft replies
- Follow-up reminders and queues
- Inbox workflow SOPs

## Constraints
- No sending without confirmation
- No legal/financial commitments
- Escalate sensitive partner or customer issues

## Output format
- Inbox state
- Priority items
- Draft replies
- Follow-up queue
- Risks and escalations
`,
  },
};

function usage() {
  console.error(
    [
      "usage:",
      "  clawbot-template-library list",
      "  clawbot-template-library show <template-id>",
      "  clawbot-template-library copy <tenant-id> <template-id> <bot-id> [--display-name <name>] [--output-dir <path>]",
    ].join("\n"),
  );
}

function nowIso() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

function getTemplate(templateId) {
  const item = TEMPLATE_LIBRARY[templateId];
  if (!item) {
    throw new Error("unknown template: " + templateId);
  }
  return item;
}

function readGuidance(item) {
  if (item.guidance_path && fs.existsSync(item.guidance_path)) {
    return fs.readFileSync(item.guidance_path, "utf8").trim() + "\n";
  }
  if (item.inline_guidance) {
    return item.inline_guidance.trim() + "\n";
  }
  throw new Error("template " + item.id + " has no guidance source");
}

function defaultOutputDir(tenantId, botId) {
  return path.join(
    "/opt/clawbot/tenants",
    tenantId,
    "config",
    "template-copies",
    botId,
  );
}

function commandList() {
  const templates = Object.values(TEMPLATE_LIBRARY).map((item) => ({
    id: item.id,
    label: item.label,
    description: item.description,
    base_specialist: item.base_specialist,
    default_display_name: item.default_display_name,
    capability_tier: item.capability_tier,
    channels: item.channels,
  }));
  console.log(JSON.stringify({ ok: true, templates }, null, 2));
}

function commandShow(templateId) {
  const item = getTemplate(templateId);
  console.log(
    JSON.stringify(
      {
        ok: true,
        template: {
          ...item,
          guidance_preview: readGuidance(item).slice(0, 600),
        },
      },
      null,
      2,
    ),
  );
}

function parseCopyArgs(args) {
  const opts = {
    displayName: "",
    outputDir: "",
  };
  for (let i = 0; i < args.length; i += 1) {
    if (args[i] === "--display-name") {
      opts.displayName = String(args[i + 1] || "").trim();
      i += 1;
      continue;
    }
    if (args[i] === "--output-dir") {
      opts.outputDir = String(args[i + 1] || "").trim();
      i += 1;
    }
  }
  return opts;
}

function commandCopy(tenantId, templateId, botId, args) {
  const item = getTemplate(templateId);
  const opts = parseCopyArgs(args);
  const outputDir = opts.outputDir || defaultOutputDir(tenantId, botId);
  const displayName = opts.displayName || item.default_display_name;

  if (fs.existsSync(outputDir)) {
    throw new Error("target already exists: " + outputDir);
  }

  fs.mkdirSync(outputDir, { recursive: true });

  const manifest = {
    schema_version: 1,
    copied_at: nowIso(),
    tenant_id: tenantId,
    bot_id: botId,
    display_name: displayName,
    template_id: item.id,
    template_label: item.label,
    description: item.description,
    base_specialist: item.base_specialist,
    capability_tier: item.capability_tier,
    channels: item.channels,
    memory_read_scopes: ["shared", "bot-private"],
    memory_write_mode: "observations-only",
    runtime_state: "tenant-owned copy",
    next_steps: [
      "Tune guidance.md for tenant-specific behavior.",
      "Review bot.json before wiring into runtime or channels.",
      "Keep this copy tenant-owned; do not edit the shared template in place.",
    ],
  };

  const readme = [
    "# Tenant bot template copy",
    "",
    "- tenant: `" + tenantId + "`",
    "- bot_id: `" + botId + "`",
    "- template: `" + item.id + "`",
    "",
    "This directory is a tenant-owned copy created from the shared template library.",
    "Safe edits:",
    "- `bot.json` for display name, channels, and tenant-specific settings",
    "- `guidance.md` for role tuning and operating rules",
    "",
    "Do not treat this as live runtime wiring by itself. It is a scaffold for later bot setup.",
    "",
  ].join("\n");

  fs.writeFileSync(path.join(outputDir, "bot.json"), JSON.stringify(manifest, null, 2) + "\n", "utf8");
  fs.writeFileSync(path.join(outputDir, "guidance.md"), readGuidance(item), "utf8");
  fs.writeFileSync(path.join(outputDir, "README.md"), readme, "utf8");

  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        templateId,
        botId,
        outputDir,
        files: [
          path.join(outputDir, "bot.json"),
          path.join(outputDir, "guidance.md"),
          path.join(outputDir, "README.md"),
        ],
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
    commandList();
    return;
  }

  if (command === "show") {
    const templateId = args[0];
    if (!templateId) {
      usage();
      process.exit(1);
    }
    commandShow(templateId);
    return;
  }

  if (command === "copy") {
    const tenantId = args[0];
    const templateId = args[1];
    const botId = args[2];
    if (!tenantId || !templateId || !botId) {
      usage();
      process.exit(1);
    }
    commandCopy(tenantId, templateId, botId, args.slice(3));
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
