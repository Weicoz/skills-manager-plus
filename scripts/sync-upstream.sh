#!/usr/bin/env bash
# Pull the latest xingkongliang/skills-manager into this fork.
#
# Usage:
#   scripts/sync-upstream.sh            # merge --no-ff (conflicts solved once)
#   scripts/sync-upstream.sh --rebase   # replay our commits on top (linear)
#
# Remotes expected by this script:
#   origin    https://github.com/Weicoz/skills-manager-plus.git
#   upstream  https://github.com/xingkongliang/skills-manager.git
set -euo pipefail

UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"
OUR_BRANCH="${OUR_BRANCH:-main}"

cd "$(dirname "$0")/.."

if ! git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
  git remote add "$UPSTREAM_REMOTE" https://github.com/xingkongliang/skills-manager.git
fi

git fetch "$UPSTREAM_REMOTE" --tags
git checkout "$OUR_BRANCH"

echo
echo "=== upstream commits we do not have ==="
git log --oneline "HEAD..$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" | head -20

if [ "${1:-}" = "--rebase" ]; then
  git rebase "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
else
  git merge --no-ff "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" \
    -m "chore(sync): merge upstream $UPSTREAM_BRANCH"
fi

cat <<'EOF'

=== where conflicts land ===
  src-tauri/src/core/content_hash.rs   fingerprint_entries / MemoizedHash / HASH_MEMO_SUPPORTED
  src-tauri/src/core/sync_metadata.rs  the memo read/write around the reindex loop

Those two files are the whole plus patch. If upstream rewrites either one,
prefer their structure and re-apply the memo on top: the invariant to keep is
"a reindex reuses a content hash only while the metadata fingerprint matches,
and never caches a hash whose tree had an unreadable file".

=== verify before pushing ===
  cd src-tauri
  cargo test --lib content_hash
  cargo test --lib sync_metadata
  cargo check --all-targets

  # behaviour check (expect a big drop on the second run)
  time target/release/skills-manager-cli skills list
  time target/release/skills-manager-cli skills list

=== ship ===
  git push origin main
EOF
