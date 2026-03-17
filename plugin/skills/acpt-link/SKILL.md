---
name: acpt-link
description: >
  Audit recently merged PRs to ensure each one has an [ACPT-###] prefix in its title and a linked Jira ticket in the ACPT board. Creates new tickets for unlinked PRs, groups related PRs thematically, updates PR titles, and adds remote PR links to Jira. Use when you want to catch up on Jira hygiene for merged work.
  Triggers: "acpt link", "link prs to jira", "jira hygiene", "acpt tickets", "link my prs", "update pr titles acpt", "jira pr sync".
---

# ACPT PR Linking Skill

Audit merged PRs by the current user, ensure each has an `[ACPT-###]` Jira ticket, create missing tickets grouped by theme, update PR titles, and add remote PR links.

## Arguments

`$ARGUMENTS` may contain:
- A since-date: `2025-01-01` or `6months` or `3months` (default: 6 months ago)
- A repo: `DataDog/dd-source` (default: current repo from `gh repo view`)
- A Jira project key: `ACPT` (default: `ACPT`)
- `--dry-run` — show what would be created/updated without making changes

## Step 0: Setup

Verify required tools:
```bash
which jira && jira me       # jira CLI at ~/.local/bin/jira
gh repo view --json nameWithOwner -q .nameWithOwner
```

Determine:
- `REPO`: from `$ARGUMENTS` or `gh repo view --json nameWithOwner -q .nameWithOwner`
- `SINCE`: parse from `$ARGUMENTS` (e.g. `6months` → subtract 6 months from today; bare date used as-is). Default: 6 months ago.
- `JIRA_PROJECT`: from `$ARGUMENTS`, default `ACPT`
- `AUTHOR`: from `gh api user -q .login`
- `ASSIGNEE_EMAIL`: from `jira me` output (e.g. `eric.chee@datadoghq.com`)

## Step 1: Fetch Unlinked PRs

Fetch all merged PRs by the author since `$SINCE`, excluding those already starting with `[ACPT-`:

```bash
gh pr list --author "$AUTHOR" --state merged --repo "$REPO" \
  --limit 200 \
  --json number,title,mergedAt,url,body \
  --jq "[.[] | select(.mergedAt >= \"$SINCE\") | select(.title | test(\"^\\\\[ACPT-\") | not)]"
```

Also note PRs that already have `[ACPT-` — they need no title update but may still need a remote link added to their Jira ticket.

**Handle pagination:** If the result contains 200 items (the max), re-run with an earlier `--search` filter or note that older PRs may be truncated.

Report: "Found N PRs without [ACPT-###] prefix since $SINCE."

If 0 unlinked PRs, report "All PRs are already linked to ACPT tickets." and stop.

## Step 2: Fetch Existing ACPT Tickets

To avoid creating duplicates, fetch existing open/recent ACPT tickets:

```bash
jira issue list -p "$JIRA_PROJECT" --plain --no-headers --paginate 0:100
jira issue list -p "$JIRA_PROJECT" --plain --no-headers --paginate 100:100
# Continue if needed
```

Also fetch ACPT Epics to identify candidate parents:
```bash
jira issue list -p "$JIRA_PROJECT" --type Epic --plain --no-headers --paginate 0:100
```

## Step 3: Group PRs Thematically

Analyze the PR titles and bodies to group them into logical themes. Use PR title keywords to identify groups. Examples of common themes (adapt based on actual PRs):

- **RMP/Runtime Management Plane migration** → parent: look for an active RMP epic
- **Atlas client SDK changes** → parent: look for an Atlas client epic
- **Atlas CLI improvements** → parent: look for an Atlas CLI epic
- **LPS/Ticino enablement** → parent: look for an LPS/Ticino epic
- **Atlas Python worker** → parent: look for a Python workers epic
- **Incidents** (title contains `incident-` or `[incident`) → type: Bug, no parent needed
- **PR0 / Temporal DNS** (title contains `[PR0]`) → parent: look for PR0 epic
- **Infrastructure / config / values files** → standalone tasks
- **Test/testbench** → group with related theme or standalone
- **Cleanup / refactoring** → group by component

For each group, identify the best parent epic by:
1. Checking if any existing ACPT epic title matches the theme
2. Checking if existing ACPT tasks already cover the work (to link rather than duplicate)
3. Defaulting to standalone (no parent) if no clear epic

Present the proposed groupings to the user **before creating anything**:

```
Proposed ticket groupings:

Group 1: "Atlas CLI improvements" (N PRs) → parent: ACPT-389
  - PR #12345: <title>
  - PR #12346: <title>

Group 2: "RMP migration for services X, Y, Z" (N PRs) → parent: ACPT-233
  - PR #12347: <title>

Group 3 (incident): "Fix XYZ (incident-NNNNN)" → Bug ticket, no parent
  - PR #12348: <title>

[... etc ...]

Proceed? (y/n)
```

If the user says no or wants changes, adjust groupings before continuing.

## Step 4: Create Jira Tickets

**Skip if `--dry-run`.**

For each group, create a Jira ticket:

```bash
KEY=$(jira issue create -p "$JIRA_PROJECT" \
  -t Task \
  -s "SUMMARY" \
  -b "BODY_WITH_PR_LINKS" \
  -a "$ASSIGNEE_EMAIL" \
  --no-input --raw 2>/dev/null \
  | grep -o '"key":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "Created: $KEY"
```

For incidents use `-t Bug`. For epics use `-t Epic`.

**Body format:**
```
One-line description of the work.

Related PRs:
- https://github.com/ORG/REPO/pull/NUM1 (title)
- https://github.com/ORG/REPO/pull/NUM2 (title)
```

**After creation:**
1. Add remote PR links:
   ```bash
   jira issue link remote "$KEY" "$PR_URL" "PR #$NUM: $TITLE"
   ```
2. If there's a parent epic, relate to it:
   ```bash
   jira issue link "$KEY" "$PARENT_EPIC" "Relates"
   ```
3. Mark as Done (all PRs are already merged):
   ```bash
   jira issue move "$KEY" Done
   ```

Track the mapping: `PR_NUMBER → ACPT_KEY` for use in Step 5.

**Use parallel agents for large batches** (>10 tickets): spin up multiple agents each handling a subset, then collect their PR→key mappings before proceeding.

## Step 5: Update PR Titles

**Skip if `--dry-run`.**

For each PR in the mapping, prepend `[ACPT-KEY]` to the title if not already present:

```bash
CURRENT_TITLE=$(gh pr view $NUM --repo "$REPO" --json title -q .title)
NEW_TITLE="[ACPT-KEY] $CURRENT_TITLE"
gh pr edit $NUM --repo "$REPO" --title "$NEW_TITLE"
```

**Preserve existing prefixes:** If the title starts with `[incident-`, `[PR0]`, `[CSI-`, `[WFENG-` etc., prepend ACPT before them:
- `[incident-12345] fix foo` → `[ACPT-NNN] [incident-12345] fix foo`

**Use parallel agents for large batches** (>15 PRs): split into groups of ~25 and run concurrently.

## Step 6: Link Existing ACPT PRs

For PRs that already had `[ACPT-###]` in the title, add them as remote links to their Jira ticket (if not already linked):

```bash
TICKET=$(echo "$TITLE" | grep -o 'ACPT-[0-9]*' | head -1)
jira issue link remote "$TICKET" "$PR_URL" "PR #$NUM: $TITLE" 2>/dev/null || true
```

## Step 7: Summary

Report a final summary:

```
ACPT Link Sync complete.

New tickets created: N
  ACPT-XXX: <summary> (M PRs)
  ...

PR titles updated: N
  #NNNNN: [ACPT-XXX] <new title>
  ...

Already linked (no changes needed): N PRs
  #NNNNN: [ACPT-XXX] <title> (already had prefix)

Skipped (dry-run): N PRs
```

## Notes

- The jira CLI is at `~/.local/bin/jira`, configured for `datadoghq.atlassian.net`
- Use `--paginate 0:100` and `--paginate 100:100` etc. for paginating jira list results (max 100 per page)
- `-P EPIC_KEY` on `jira issue create` may fail with "Epic Link" error — use `jira issue link KEY EPIC "Relates"` instead
- `--raw` flag on `jira issue create` outputs JSON; extract key with `grep -o '"key":"[^"]*"'`
- For large batches, always use parallel agents to stay under context limits
- Ignore PRs to repos matching `slog`, `slop`, or `lukrehulk` in the repo name
- All created tickets should be assigned to `$ASSIGNEE_EMAIL`
