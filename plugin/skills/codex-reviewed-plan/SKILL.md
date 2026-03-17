---
description: Draft an implementation plan from a description, then iteratively review it with codex exec and refine until no actionable issues remain.
---

# Codex Reviewed Plan Skill

Takes a description of what to implement, drafts a plan, then repeatedly runs `codex exec` to review it, addresses valid feedback, and loops until codex finds no actionable issues. Ends by entering plan mode so the user can approve and implement.

## Arguments

`$ARGUMENTS` may be:
- A description of what to implement (e.g. "add retry logic to the LPS client")
- A path to an existing plan file to review as-is (e.g. `/tmp/plan.md`)
- Empty — ask the user what they want to implement before proceeding

## Step 0: Launch Isolated Agent

Use the `Agent` tool (subagent_type: `general-purpose`) to run the entire
plan-draft-and-review workflow in an isolated context. Pass:

- The value of $ARGUMENTS (description, file path, or empty)
- The current working directory
- The full instructions from Steps 1–4 of this skill

Wait for the agent to complete and present its findings to the user.

---

## Step 1: Determine Input Mode

Parse `$ARGUMENTS`:
- If it looks like a file path and the file exists → set `PLAN_FILE` to that path and skip to Step 3 (Review Loop)
- If it is a non-empty description → proceed to Step 2 (Draft Plan)
- If empty → ask the user: "What do you want to implement?" and use their response as the description

For new plans, generate a timestamped path to avoid collisions:
```bash
PLAN_FILE="/tmp/plan-$(date +%Y%m%d-%H%M%S).md"
```

## Step 2: Draft the Plan

Using the description, explore the relevant parts of the codebase and draft a concrete implementation plan. The plan should cover:

- **Goal**: one-sentence summary of what is being implemented
- **Background**: relevant context (existing code, patterns, constraints)
- **Steps**: ordered list of concrete changes, each specifying:
  - Which file(s) to modify or create
  - What change to make and why
  - Any preconditions or dependencies on other steps
- **Edge cases**: error paths, boundary conditions, and how each is handled
- **Testing**: how the changes will be verified

Read the relevant source files before writing — do not assume file locations, function signatures, or existing patterns without verifying them first.

Write the completed plan to `PLAN_FILE` using the Write tool.

**Show the user the drafted plan and ask:**
> "Plan drafted and saved to `$PLAN_FILE`. Does this look right, or would you like to adjust anything before I run codex review?"

Wait for confirmation before proceeding. If the user requests changes, apply them to the plan file and re-confirm. Once the user is happy, continue to Step 3.

## Step 3: Run Review Loop

Initialize before the loop:
```
PLAN_UPDATES=""   # accumulates one-line descriptions of plan edits per iteration
ITERATION=0
```

Repeat the following loop until the review output contains no valid, actionable issues (maximum 10 iterations):

### Step 3a: Run `codex exec` to review the plan

**Iteration 1** — run a full review from scratch. Replace `$PLAN_FILE` with the actual file path in the command:

```bash
codex exec "You are reviewing an implementation plan stored at $PLAN_FILE.

First, read the plan at $PLAN_FILE.

Then, for each concrete claim in the plan (file paths, function names, type signatures, existing patterns), verify it against the actual codebase by reading the referenced files. Do not assume anything is correct without checking.

Identify any issues across these categories:
1. Logical gaps or missing steps
2. Incorrect assumptions about the codebase, APIs, or environment (check the actual files)
3. Edge cases or error paths not handled
4. Ordering problems (steps that depend on later steps, or missing prerequisites)
5. Simpler or better approaches that the plan overlooks

For each issue, output it in this format:
  [P1|P2|P3] <short title> — <explanation>

Priority guide:
  P1 = Would cause the implementation to be wrong or broken
  P2 = Would leave an important gap or create future problems
  P3 = Minor improvement or polish

If the plan is sound with no actionable issues, output exactly:
  LGTM

Do NOT make any changes to files. Only review and report." \
  -o /tmp/codex-reviewed-plan-output.txt 2>&1 | tee /tmp/codex-reviewed-plan-raw.txt
```

If `-o` flag is not supported or fails, fall back to:
```bash
codex exec "..." 2>&1 | tee /tmp/codex-reviewed-plan-raw.txt
wc -l /tmp/codex-reviewed-plan-raw.txt
```

**Iterations 2+** — resume the existing session with a targeted prompt listing what was updated:
```bash
codex exec resume --last \
  "I applied the following updates to the plan since the last review:
$PLAN_UPDATES

Please re-check the plan for any remaining issues.
Output each issue as [P1|P2|P3] <short title> — <explanation>.
If no actionable issues remain, output exactly: LGTM" \
  -o /tmp/codex-reviewed-plan-output.txt 2>&1 | tee /tmp/codex-reviewed-plan-raw.txt
```

Then read `/tmp/codex-reviewed-plan-output.txt` for analysis.

### Step 3b: Parse and Evaluate Issues

Read `/tmp/codex-reviewed-plan-raw.txt` and extract all reported issues. For each issue:

**Mark as INVALID (skip) if:**
- The concern is about something outside the plan's stated scope
- The issue is based on a wrong assumption about the codebase — verify by reading the relevant file before deciding
- It is purely stylistic with no functional impact
- It duplicates an issue already addressed in a previous iteration

**Mark as VALID (address) if:**
- It identifies a genuine logical gap, missing step, or incorrect assumption
- It calls out an edge case or error path the plan does not cover
- It points out a prerequisite step that is missing or out of order
- Addressing it would meaningfully improve the correctness or completeness of the plan

### Step 3c: Report Findings

After evaluating all issues, display a summary:

```
Iteration N review found X issues total:
  - Y valid issues to address
  - Z invalid/skipped issues

Valid issues:
  [list each valid issue with priority and description]

Skipped issues (with reason):
  [list each skipped issue and why it was skipped]
```

### Step 3d: Check for Completion

If the output contains `LGTM`, or if there are zero valid issues, exit the loop and go to Step 4 (Done).

If the maximum iteration count (10) is reached with remaining valid issues, report them to the user and ask whether to continue for another 10 iterations. If yes, reset the counter and continue.

### Step 3e: Update the Plan

Reset the updates accumulator so only this iteration's changes are sent to the next resume prompt:
```
PLAN_UPDATES=""
```

For each valid issue, in priority order (P1 first):

1. **Read the current plan file** to understand the relevant section
2. **Verify the issue still applies** — a previous edit may have resolved it
3. If the issue references codebase details, **read the relevant source file** to confirm before editing
4. **Edit the plan** using the Edit tool to address the issue

After each plan edit is applied, append a one-line description to `PLAN_UPDATES`:
```
PLAN_UPDATES="$(printf '%s\n- <section/topic>: <what was changed>' "$PLAN_UPDATES")"
```

**Editing guidelines:**
- Make targeted edits — do not rewrite sections unaffected by the issue
- Preserve the plan's existing structure and style
- If an issue is ambiguous or the correct fix is unclear, skip it and flag it for the user

After all updates are applied, increment `ITERATION` and go back to **Step 3a** for the next iteration.

## Step 4: Done

Present a final summary:

```
Plan approved by codex after N iteration(s).

Changes made during review:
  - [list of improvements, one per addressed issue]

Skipped feedback (not incorporated):
  - [feedback evaluated as invalid, with brief reason]

Plan saved to: $PLAN_FILE
```

Then display the full contents of `PLAN_FILE`.

Finally, ask the user:
> "Would you like me to implement this plan now?"

If yes, enter plan mode using EnterPlanMode with the contents of the plan, so the user can give final approval before implementation begins.

## Notes

- Only modify the plan file during this skill — never touch source code files
- If codex produces a tool error or auth failure (non-zero exit, no issue list), stop and report the error to the user
- The plan file is left on disk; run `/codex-reviewed-plan $PLAN_FILE` to re-review it after manual edits
