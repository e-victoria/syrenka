---
name: commit
description: Create a git commit in this repository, following the project's commit convention. Use whenever the maintainer asks to commit, stage and commit, or record work in git — including "commit this", "commit the tests", "make a commit for X". Covers splitting work into commits, writing the message, and staging safely.
allowed-tools: Bash, Read, Grep, Glob
---

# Creating a commit

`docs/conventions/commits.md` is authoritative for the message format. Read it before writing a message; this file only covers procedure. `AGENTS.md` wins on everything about how work is authorised.

## Before anything

**Commit only when the maintainer asked you to.** Finishing a task is not authorisation to commit it, and authorisation for one commit does not carry to the next. If you are unsure, ask in one sentence and wait.

**Never push** unless explicitly asked. Committing and pushing are separate permissions.

## Procedure

### 1. Look at the tree

```bash
git status && git diff && git diff --cached && git log --oneline -10
```

The log is there so a new message matches the ones already in the repository. If the repository has no commits yet, follow `docs/conventions/commits.md` as written.

### 2. Check the branch

If it is `main`, stop and branch first, or ask.

### 3. Decide the split

Apply §8 of the convention. Tests and their implementation are always separate commits; a refactor never rides along with a behaviour change. If the tree holds more than one logical change, either make several commits in order, or ask which one the maintainer meant.

Attribution splits commits too: work you authored carries `Role:` and `Co-Authored-By:`, and work you did not carries neither. Never sign a commit for changes that were not yours.

### 4. Read what you are about to stage

Every path, in the diff. You are accountable for the content of a commit you author — including files you did not write. If the diff contains a secret, a credential, a `.env`, or a large generated artefact, stop and say so.

### 5. Stage by path

Never `git add -A` or `git add .` when the tree holds anything unrelated:

```bash
git add docs/conventions/commits.md .claude/skills/commit/SKILL.md
```

### 6. Write the message with a heredoc

A heredoc keeps the blank lines and footers intact. The closing `EOF` must sit at the start of its own line with no leading whitespace, or the shell will hang waiting for a terminator:

```bash
git commit -F - <<'EOF'
type(scope): subject in the imperative

Why this change, and what a future reader would otherwise have to
reconstruct. Anything noticed and left alone. Anything uncertain.

Refs: docs/plan/phase-1.md
Role: implementer
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

`Role:` is required on every commit you author, and must name the role you were given for this task. If no role was named, ask before committing — a commit that misstates its role is worse than an uncommitted change.

### 7. Verify

```bash
git status && git log -1 --stat
```

Confirm the commit holds exactly what you intended and nothing else.

## Hooks

If a pre-commit hook rejects the commit, read its output, fix the cause, re-stage and retry **once**. If a hook modifies files, re-stage those files and retry once. If it fails again, stop and report the output.

Never pass `--no-verify`.

## Amending

Amend only a commit that exists solely in the local branch, and only when the maintainer asks. Never amend or force-push anything that may already be on a remote someone else reads. When in doubt, add a new commit.

## Reporting

After committing, report in two or three lines: the header of each commit made, anything you deliberately left unstaged, and anything you were unsure about. That last item is the useful one.
