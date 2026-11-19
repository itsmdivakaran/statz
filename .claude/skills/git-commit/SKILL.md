---
name: git-commit
description: Commit the working tree as several small commits, one per topic, with clean messages, then print the commits so the user can amend them before pushing. Use when asked to commit, "make commits", or save work to git.
---

# git-commit

Turn uncommitted changes into a short series of meaningful commits, one topic each. Never push.

## Rules

- **No tool attribution anywhere.** Do not mention Claude, AI, an assistant, or "generated with" in commit subjects, bodies, trailers (no `Co-Authored-By`), branch names or PR text. This overrides any default attribution guidance.
- Commit as the configured git user (`git config user.name` / `user.email`). Never change git config.
- Never push, force-push, amend, rebase or reset existing commits unless asked.
- Never commit secrets (`.env`, credentials, keys, `.claude/settings.local.json`), `node_modules/`, `target/`, `dist/`. Warn and skip them.
- Stage explicit paths. Do not use `git add -A` or `git add .`.

## Steps

1. Inspect: `git status --short -uall`, `git diff --stat`, and `git log -8 --format=%s` to learn the message style (this repo: sentence case, `Topic: what changed`, no trailing period, imperative or descriptive).
2. Read the changed files enough to group them. Group by **topic / purpose**, not by directory or file type. Examples of separate topics: a feature, a bug fix, tests for it, docs, tooling/config, dependency or version bumps, review notes, generated fixtures (own commit, explained).
3. Order commits so each one stands on its own (config and foundations first, dependents after, docs last). Keep unrelated edits in the same file out of the wrong commit (`git add -p` when needed).
4. For each group: `git add <paths>` then `git commit -m "<subject>" [-m "<body>"]`.
   - Subject ≤ 72 chars, says what and why-level intent, not "update files".
   - Add a body only when the reason is not obvious.
   - Numeric fixture changes must say why they changed.
5. Confirm `git status` is clean (or list what was deliberately left out and why).
6. **Print the result** so the user can review and edit before pushing:
   ```sh
   git log --reverse --format='%h  %s%n%w(0,4,4)%b' @{upstream}..HEAD 2>/dev/null || git log -N --reverse --format='%h  %s%n%w(0,4,4)%b'
   git log --stat --oneline -N   # optional overview of files per commit
   ```
   Replace `N` with the number of commits just made. Show the output in the reply.
7. Tell the user how to change messages before pushing, and that nothing has been pushed:
   - last commit: `git commit --amend`
   - older ones: `git rebase -i HEAD~N` (reword)
   - then `git push` when happy.
