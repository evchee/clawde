---
description: Iteratively run codex exec review, evaluate issues, fix valid ones, and repeat until clean
---

# Codex Review Fix Skill

Repeatedly runs `codex exec review --base <BASE_BRANCH>`, evaluates reported issues for correctness, fixes valid ones, and loops until the review passes with no actionable issues.

## Arguments

`$ARGUMENTS` may contain a base branch (e.g. `main`, `origin/main`). If not provided, auto-detect the parent branch.

## Step 0: Launch Isolated Agent

Use the `Agent` tool (subagent_type: `general-purpose`) to run the entire review in an isolated context. Pass the following as the prompt:

- The base branch from `$ARGUMENTS` (or instruct the agent to auto-detect using the steps below)
- The current working directory
- The full instructions from Steps 1–3 of this skill

Wait for the agent to complete and summarise its findings to the user.

---

## Step 1: Determine Base Branch

Parse `$ARGUMENTS`:
- If a branch name is provided, use it as `BASE_BRANCH`
- Otherwise, auto-detect the parent branch using the following priority order:

**Auto-detection (try in order, use the first that succeeds):**

1. **Graphite (gt)** — if `gt` is available, get the parent branch of the current stack entry:
   ```bash
   gt log short 2>/dev/null | grep -A1 "$(git branch --show-current)" | tail -1 | tr -d ' *'
   ```
   Or alternatively:
   ```bash
   gt branch show 2>/dev/null | grep "Parent:" | awk '{print $2}'
   ```

2. **Git upstream tracking branch** — check if the current branch tracks an upstream:
   ```bash
   git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null | sed 's|^origin/||'
   ```

3. **Fallback to `main`**

After determining the candidate, verify it exists locally or remotely:
```bash
git rev-parse --verify "$BASE_BRANCH" 2>/dev/null || git rev-parse --verify "origin/$BASE_BRANCH" 2>/dev/null
```

If neither exists, inform the user and stop.

Tell the user which base branch was selected and how it was detected.

## Step 2: Run Review Loop

Repeat the following loop until the review output contains no valid, actionable issues (maximum 10 iterations to avoid infinite loops):

### Step 2a: Run `codex exec review`

Save the review output to a temp file to avoid truncation:
```bash
codex exec review --base "$BASE_BRANCH" -o /tmp/codex-review-output.txt 2>&1 | tee /tmp/codex-review-raw.txt
```

If `-o` flag is not supported or fails, run without it:
```bash
codex exec review --base "$BASE_BRANCH" 2>&1 | tee /tmp/codex-review-raw.txt
wc -l /tmp/codex-review-raw.txt
```

Then read the output file for analysis.

### Step 2b: Parse and Evaluate Issues

Read the review output and extract all reported issues. For each issue:

**Evaluate validity by asking:**
1. Is this issue about code that was actually changed (not just context lines)?
2. Is the issue technically correct — does the described problem actually exist in the code?
3. Is the suggested fix sound — would it compile, maintain behavior, and not introduce new bugs?
4. Is this a real bug/correctness issue vs. a style preference or minor nit?

**Mark as INVALID (skip) if:**
- The issue is about code that was NOT modified in this PR/branch
- The suggestion is incorrect or would break functionality
- The issue is a false positive (e.g., flagging correct code as wrong)
- The issue is purely cosmetic with no functional impact (unless the codebase has strict style enforcement)
- The issue is about a test file that intentionally uses hardcoded values or mocks
- The suggestion conflicts with the existing patterns in this codebase

**Mark as VALID (fix) if:**
- The issue identifies a genuine bug, logic error, or correctness problem
- The issue is about code in scope (changed in this PR/branch)
- The fix is clearly correct and safe to apply
- The issue would cause test failures, runtime errors, or incorrect behavior

### Step 2c: Report Findings

After evaluating all issues, display a summary:

```
Iteration N review found X issues total:
  - Y valid issues to fix
  - Z invalid/skipped issues

Valid issues:
  [list each valid issue with file:line and description]

Skipped issues (with reason):
  [list each skipped issue and why it was skipped]
```

### Step 2d: Check for Completion

If there are **zero valid issues**, exit the loop and go to Step 3 (Done).

If the maximum iteration count (10) is reached with remaining valid issues, report the remaining issues to the user and ask whether to continue for another 10 iterations. If the user says yes, reset the iteration counter to 0 and continue the loop.

### Step 2e: Fix Valid Issues

For each valid issue, in order of file path (to minimize context switching):

1. **Read the affected file** to understand the full context around the issue
2. **Verify the issue still exists** (a previous fix may have resolved it)
3. **Apply the fix** using the Edit tool
4. After all fixes in a Go file: run `gofmt -w <file>` to format
5. After fixing all files: if BUILD files may be affected, update with Gazelle (see `.claude/rules/bazel.md`)

**Important fix guidelines:**
- Make the minimal change needed to address the issue — don't refactor surrounding code
- Do NOT fix issues in files you weren't asked to modify beyond what the review flagged
- If a fix requires changes in multiple files (e.g. updating a function signature and all callers), assess whether it's safe to do so; if risky, note it and skip with explanation
- If unsure whether a fix is correct, skip it and explain why to the user

After all fixes are applied, go back to **Step 2a** for the next iteration.

## Step 3: Done

When the review passes with no valid issues (or issues found are all invalid), present a final summary:

```
Codex review is clean after N iteration(s).

Total fixes applied:
  - X issues fixed across Y files

Files modified:
  - [list of files changed]

Skipped issues (not fixed):
  - [any issues that were evaluated as invalid, with brief reason]
```

If any valid issues could not be fixed (e.g. complex multi-file changes), clearly list them with context so the user can address them manually.

## Notes

- Always prefer fixing the root cause rather than suppressing a linter warning
- When a fix in one file resolves multiple reported issues, note that in the summary
- If `codex exec review` exits with a non-zero status unrelated to issues found (e.g. tool error, auth failure), stop and report the error to the user
- This skill modifies files in the working tree — do NOT commit changes automatically; leave that to the user
