# skills-manager-plus

Fork of [xingkongliang/skills-manager](https://github.com/xingkongliang/skills-manager) that keeps the
upstream feature set and changes exactly one thing: how fast a reindex is.

Upstream MIT license and copyright are unchanged. See `LICENSE`.

## What is different

`reindex_from_metadata` runs on every GUI launch and every CLI invocation. Upstream
recomputes each skill's SHA-256 by reading every file under it and parses every metadata
JSON file under `.skills-manager`, so on a 10k-file library each command costs seconds
and tens of MB.

This fork adds two cooperative speedups:
1. **Metadata manifest fingerprint**: skips reading, deserializing, and rewriting 1000+
   metadata JSON files when `.skills-manager` has not changed.
2. **Per-skill content hash memo**: remembers `(metadata fingerprint, content hash)`
   per skill in `settings`, reusing hashes when file ctime and size are untouched.

Fingerprint covers relative path, size, `ctime` (nanoseconds) and exec bits.
`ctime` is what makes it sound: `cp -p`, `rsync --times`, `unzip` and `tar -x`
can restore an old mtime, but not the inode change time.

Guards, because a stale hash silently freezes copy-mode deployments:

- the memos are disabled on platforms without `ctime` (Windows), where a preserved
  mtime would fake "unchanged"
- a hash whose tree had an unreadable file is never cached
- a memo hit that disagrees with `skills.content_hash` is discarded; the database wins
- both memos are rebuilt in full once older than a day (`HASH_MEMO_FULL_VERIFY_SECS`),
  and only a full rebuild advances that timestamp
- entries must look like SHA-256 digests; `settings` read failures degrade to
  "no memo" instead of aborting the reindex
- `settings` is written only when memo/manifest actually changed
- single-file mutations invalidate the manifest key in O(1) without O(n^2) tree rescans
- vanished skill directories clean up orphan metadata files immediately

Measured on 466 skills / 1,156 metadata JSONs / 8,875 files: **0.77s → 0.14s**, **24MB → 8.15MB**, with all
hashes identical to a full recompute.

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
