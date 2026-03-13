#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF' >&2
usage: clawbot-agents-pr.sh <agent-id> <topic-slug> <repo-path> [summary]

Creates a branch and pull request in the private clawbot-agents repo using the
configured GitHub App credentials.

Arguments:
  agent-id     Internal agent id, e.g. podcast_media
  topic-slug   Short branch/PR slug, e.g. social-tone
  repo-path    Local path to a clawbot-agents working tree with changes ready
  summary      Optional PR summary; defaults to topic-slug with dashes replaced
               by spaces

Environment overrides:
  CLAWBOT_AGENTS_APP_ID_FILE
  CLAWBOT_AGENTS_INSTALLATION_ID_FILE
  CLAWBOT_AGENTS_APP_KEY_FILE
  CLAWBOT_AGENTS_BASE_BRANCH
EOF
  exit 1
}

[ "$#" -ge 3 ] || usage

agent_id="$1"
topic_slug="$2"
repo_path="$3"
summary="${4:-${topic_slug//-/ }}"

app_id_file="${CLAWBOT_AGENTS_APP_ID_FILE:-/opt/clawbot-root/bootstrap/clawbot-agents-pr-bot.app_id}"
installation_id_file="${CLAWBOT_AGENTS_INSTALLATION_ID_FILE:-/opt/clawbot-root/bootstrap/clawbot-agents-pr-bot.installation_id}"
app_key_file="${CLAWBOT_AGENTS_APP_KEY_FILE:-/opt/clawbot-root/bootstrap/clawbot-agents-pr-bot.pem}"
base_branch="${CLAWBOT_AGENTS_BASE_BRANCH:-main}"

for path in "$app_id_file" "$installation_id_file" "$app_key_file"; do
  [ -r "$path" ] || { echo "missing required credential file: $path" >&2; exit 1; }
done

[ -d "$repo_path/.git" ] || { echo "repo path is not a git working tree: $repo_path" >&2; exit 1; }

app_id="$(tr -d '[:space:]' < "$app_id_file")"
installation_id="$(tr -d '[:space:]' < "$installation_id_file")"

base64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

create_jwt() {
  local now exp header payload header_b64 payload_b64 signing_input sig
  now="$(date +%s)"
  exp="$((now + 540))"
  header='{"alg":"RS256","typ":"JWT"}'
  payload="$(printf '{"iat":%s,"exp":%s,"iss":"%s"}' "$now" "$exp" "$app_id")"
  header_b64="$(printf '%s' "$header" | base64url)"
  payload_b64="$(printf '%s' "$payload" | base64url)"
  signing_input="${header_b64}.${payload_b64}"
  sig="$(
    printf '%s' "$signing_input" \
      | openssl dgst -binary -sha256 -sign "$app_key_file" \
      | base64url
  )"
  printf '%s.%s' "$signing_input" "$sig"
}

app_jwt="$(create_jwt)"

installation_token="$(
  curl -fsSL \
    -X POST \
    -H "Authorization: Bearer ${app_jwt}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/app/installations/${installation_id}/access_tokens" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])'
)"

remote_url="$(git -C "$repo_path" remote get-url origin)"
owner_repo="$(
  python3 - "$remote_url" <<'PY'
import re, sys
url = sys.argv[1]
patterns = [
    r'github\.com[:/](?P<owner>[^/]+)/(?P<repo>[^/.]+)(?:\.git)?$',
]
for pattern in patterns:
    m = re.search(pattern, url)
    if m:
        print(f'{m.group("owner")}/{m.group("repo")}')
        sys.exit(0)
raise SystemExit(f"could not parse GitHub owner/repo from remote URL: {url}")
PY
)"

owner="${owner_repo%/*}"
repo="${owner_repo#*/}"
https_remote_url="https://x-access-token:${installation_token}@github.com/${owner_repo}.git"

timestamp="$(date +%Y%m%d-%H%M%S)"
branch="agent/${agent_id}/${topic_slug}-${timestamp}"
commit_message="agent(${agent_id}): ${summary}"
pr_title="${agent_id}: ${summary}"

git -C "$repo_path" fetch "$https_remote_url" "$base_branch"
git -C "$repo_path" checkout -B "$branch" FETCH_HEAD

if [ -z "$(git -C "$repo_path" status --short)" ]; then
  echo "no changes present in $repo_path" >&2
  exit 1
fi

git -C "$repo_path" add -A
git -C "$repo_path" -c user.name='clawbot-agents-pr-bot[bot]' -c user.email='clawbot-agents-pr-bot[bot]@users.noreply.github.com' commit -m "$commit_message"

git -C "$repo_path" push "$https_remote_url" "$branch"

pr_body_file="$(mktemp)"
cat > "$pr_body_file" <<EOF
## Reason

Agent-authored proposal for \`${agent_id}\`.

## Observed behavior

- See commit diff

## Files changed

- See commit diff

## Expected outcome

- Improves \`${agent_id}\` behavior without directly mutating protected \`${base_branch}\`

## Risks

- Prompt drift or overcorrection if merged without review
EOF

pr_url="$(
  curl -fsSL \
    -X POST \
    -H "Authorization: Bearer ${installation_token}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${owner}/${repo}/pulls" \
    -d @- <<EOF
{
  "title": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$pr_title"),
  "head": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$branch"),
  "base": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$base_branch"),
  "body": $(python3 -c 'import json,sys; print(json.dumps(open(sys.argv[1]).read()))' "$pr_body_file")
}
EOF
)"

rm -f "$pr_body_file"

printf '%s\n' "$pr_url" | python3 -c 'import json,sys; print(json.load(sys.stdin)["html_url"])'
