#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${HOST:-91.107.207.3}"
SSH_KEY="${SSH_KEY:-/home/mcintosh/.ssh/mcintosh-clawbot}"
SSH_OPTS=(
  -i "$SSH_KEY"
  -o StrictHostKeyChecking=no
)

usage() {
  cat <<'EOF'
usage:
  scripts/sync-node-assets.sh tools
  scripts/sync-node-assets.sh templates
  scripts/sync-node-assets.sh all
  scripts/sync-node-assets.sh tool <tool-name>
  scripts/sync-node-assets.sh template <template-path>

examples:
  scripts/sync-node-assets.sh tools
  scripts/sync-node-assets.sh tool clawbot-template-library
  scripts/sync-node-assets.sh templates
  scripts/sync-node-assets.sh template specialists/qa.md

env overrides:
  HOST=91.107.207.3
  SSH_KEY=/home/mcintosh/.ssh/mcintosh-clawbot
EOF
}

declare -A TOOL_MAP=(
  [clawbot-template-library]="scripts/bot-template-library.mjs:/usr/local/bin/clawbot-template-library:0755"
  [clawbot-import-podcast-transcripts]="scripts/import-podcast-transcripts.mjs:/usr/local/bin/clawbot-import-podcast-transcripts:0755"
  [clawbot-observation-review]="scripts/observation-review.mjs:/usr/local/bin/clawbot-observation-review:0755"
  [clawbot-memory-reindex]="scripts/memory-reindex.mjs:/usr/local/bin/clawbot-memory-reindex:0755"
  [clawbot-qmd-tenant]="scripts/qmd-tenant-wrapper.mjs:/usr/local/bin/clawbot-qmd-tenant:0755"
  [clawbot-work-queue]="scripts/work-queue.mjs:/usr/local/bin/clawbot-work-queue:0755"
)

TEMPLATE_ROOT_LOCAL="modules/clawbot_server/templates/agent-config"
TEMPLATE_ROOT_REMOTE="/opt/clawbot/config/agent-config"

run_ssh() {
  ssh "${SSH_OPTS[@]}" "root@${HOST}" "$@"
}

sync_file() {
  local local_rel="$1"
  local remote_path="$2"
  local mode="$3"
  local local_path="${ROOT_DIR}/${local_rel}"

  if [[ ! -f "$local_path" ]]; then
    printf 'missing local file: %s\n' "$local_path" >&2
    exit 1
  fi

  printf 'sync: %s -> %s\n' "$local_rel" "$remote_path"
  run_ssh "mkdir -p '$(dirname "$remote_path")'"
  cat "$local_path" | run_ssh "tmp=\$(mktemp); cat >\"\$tmp\"; install -m ${mode} \"\$tmp\" \"$remote_path\"; rm -f \"\$tmp\""
}

sync_tool() {
  local tool_name="$1"
  local spec="${TOOL_MAP[$tool_name]:-}"
  if [[ -z "$spec" ]]; then
    printf 'unknown tool: %s\n' "$tool_name" >&2
    exit 1
  fi

  IFS=':' read -r local_rel remote_path mode <<<"$spec"
  sync_file "$local_rel" "$remote_path" "$mode"
}

sync_all_tools() {
  local tool_name
  for tool_name in "${!TOOL_MAP[@]}"; do
    sync_tool "$tool_name"
  done
}

template_local_rel() {
  local template_rel="$1"
  printf '%s/%s' "$TEMPLATE_ROOT_LOCAL" "$template_rel"
}

template_remote_path() {
  local template_rel="$1"
  printf '%s/%s' "$TEMPLATE_ROOT_REMOTE" "$template_rel"
}

sync_template() {
  local template_rel="$1"
  sync_file "$(template_local_rel "$template_rel")" "$(template_remote_path "$template_rel")" "0644"
}

sync_all_templates() {
  local template_rel
  while IFS= read -r template_rel; do
    sync_template "$template_rel"
  done < <(
    cd "${ROOT_DIR}/${TEMPLATE_ROOT_LOCAL}" && find . -type f | sed 's#^\./##' | sort
  )
}

main() {
  local command="${1:-}"
  case "$command" in
    tools)
      sync_all_tools
      ;;
    templates)
      sync_all_templates
      ;;
    all)
      sync_all_tools
      sync_all_templates
      ;;
    tool)
      local name="${2:-}"
      [[ -n "$name" ]] || { usage; exit 1; }
      sync_tool "$name"
      ;;
    template)
      local rel="${2:-}"
      [[ -n "$rel" ]] || { usage; exit 1; }
      sync_template "$rel"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
