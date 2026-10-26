# skills-manager-plus

Fork of [xingkongliang/skills-manager](https://github.com/xingkongliang/skills-manager) that keeps the
upstream feature set and changes exactly one thing: how fast a reindex is.

Upstream MIT license and copyright are unchanged. See `LICENSE`.

## What is different

`reindex_from_metadata` runs on every GUI launch and every CLI invocation. Upstream
recomputes each skill's SHA-256 by reading every file under it, so on a 10k-file
library each command costs seconds and tens of MB.

This fork remembers `(metadata fingerprint, content hash)` per skill in `settings`.
A reindex still walks the tree, but when the fingerprint matches it reuses the hash
instead of reading the files.

Fingerprint covers relative path, size, `ctime` (nanoseconds) and exec bits.
`ctime` is what makes it sound: `cp -p`, `rsync --times`, `unzip` and `tar -x`
can restore an old mtime, but not the inode change time.

Guards, because a stale hash silently freezes copy-mode deployments:

- the memo is disabled on platforms without `ctime` (Windows), where a preserved
  mtime would fake "unchanged"
- a hash whose tree had an unreadable file is never cached
- a memo hit that disagrees with `skills.content_hash` is discarded; the database wins
- the memo is rebuilt in full once it is older than a day, and only a full rebuild
  advances that timestamp
- entries must look like SHA-256 digests; `settings` read failures degrade to
  "no memo" instead of aborting the reindex
- `settings` is written only when the memo actually changed

Measured on 464 skills / 9941 files: **4.23s → 0.61s**, **54MB → 23MB**, with all
464 hashes identical to a full recompute.

## Keeping up with upstream

```bash
scripts/sync-upstream.sh          # merge (default)
scripts/sync-upstream.sh --rebase # linear history
```

The patch is confined to two files:

- `src-tauri/src/core/content_hash.rs` — `fingerprint_entries`, `MemoizedHash`,
  `hash_entries_with_status`, `HASH_MEMO_SUPPORTED`
- `src-tauri/src/core/sync_metadata.rs` — the memo around the reindex loop

Conflicts should only ever land there. Keep the invariant: *reuse a content hash only
while the metadata fingerprint matches, and never cache a hash whose tree had an
unreadable file.*

The version string is left alone on purpose, so it always tracks the upstream release
this fork is based on.
