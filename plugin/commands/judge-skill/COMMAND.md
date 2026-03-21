---
name: judge-skill
description: "Analyse a Claude Code skill or command and output a structured assessment using the stopgap skill framework: verdict (Delete / Aggressively Trim / Phase Out / Keep), what it does, unwanted triggering risk (for skills), assessment, and underlying issues categorised as CLI Stopgap / Doc Stopgap / Process Stopgap / Not an Issue."
---

# Judge Skill

Analyse a Claude Code skill or command and produce a structured assessment using the stopgap skill framework.

## Arguments

`$ARGUMENTS` should be one of:
- A skill name (e.g. `rapid`, `conductor`, `atlas:go-test`)
- A path to a skill file or directory
- A plugin marketplace name and skill (e.g. `datadog-claude-plugins/dd/skills/conductor`)

If no argument is provided, ask the user which skill to analyse.

## Verdicts

There are exactly four possible verdicts. Apply the first one that fits:

- **Delete** — The skill provides no value Claude doesn't already have natively. Remove entirely, possibly with a one-line AGENTS.md entry if the tool's existence is non-obvious.
- **Aggressively Trim** — The skill contains real non-obvious constraints or gotchas, but is buried in boilerplate, examples, or `--help` redocumentation. Strip to a thin signpost (~20-50 lines): key constraints, what NOT to do, existence of the CLI. No examples, no step-by-step tutorials.
- **Phase Out** — The skill's value exists only because underlying tooling (CLI, docs, process) is missing. The skill is correct to exist _now_ but should be deleted once the root gaps are addressed.
- **Keep** — The skill requires genuine LLM judgment that cannot be replaced by a CLI command, better docs, or process change. Minor trimming only.

## Step 1: Locate and Read All Files

Find the skill's files. Check these locations in order:
1. The path provided in `$ARGUMENTS` directly
2. `~/.claude/plugins/marketplaces/*/skills/$ARGUMENTS/`
3. `~/.claude/plugins/cache/*/skills/$ARGUMENTS/`
4. `~/evchee/clawde/plugin/skills/$ARGUMENTS/`

Read **every file** in the skill directory: SKILL.md or COMMAND.md, all companion docs, all scripts, all examples. Note the file count and total line count.

If the skill has sub-agents or agent definitions, read those too (typically in a sibling `agents/` directory).

## Step 2: Research Ground Truth

For each CLI tool the skill mentions, verify what actually exists today:

- Run `<tool> --help` or `<tool> <subcommand> --help` to confirm what flags and subcommands exist
- Search the codebase for the CLI source if available: does the subcommand the skill documents actually exist?
- For each "non-obvious" constraint the skill documents, check: is it in `--help`? Is it in a README? Is it derivable from reading existing code in the repo?
- For each error table or troubleshooting entry, check: does a `doctor` or `validate` command already handle this?

The goal is to distinguish between:
- Knowledge the skill invents (not derivable from any tool or code)
- Knowledge the skill duplicates (already in `--help`, README, or existing code patterns)

## Step 3: Identify the Core Value

Ask these questions to find what, if anything, is genuinely non-obvious:

1. **Tribal knowledge**: Facts only discoverable by getting burned or asking the right person (e.g. "Tuesday-only deploys", "use GovSlack not regular Slack").
2. **Silent failure modes**: Behaviours that succeed with wrong results and produce no error (e.g. "schedules silently don't run without `schedules.enabled: true`").
3. **Misleading error messages**: Cases where the CLI produces a confusing error when a simple rule is violated.
4. **Judgment orchestration**: Multi-step workflows that require LLM judgment at each step — not just command execution.
5. **Cross-system coordination**: Workflows that span multiple tools with no single CLI owning the flow.

Knowledge that passes one of these tests is genuinely non-obvious. Everything else is documentation or code generation that belongs elsewhere.

## Step 4: Identify Underlying Issues

For each gap the skill compensates for, categorise it:

- **CLI Stopgap** — A command, subcommand, flag, or validation rule that doesn't exist in the CLI but should. The skill exists because the CLI is incomplete.
- **Doc Stopgap** — Information that should be in a `--help` output, README, godoc comment, or SDK documentation but isn't. The skill is a substitute for missing documentation.
- **Process Stopgap** — A coordination, ownership, or workflow gap that no single tool owns. Often spans multiple teams or systems.
- **Not an Issue** — The skill compensates for something that is already provided natively by Claude or standard tools (e.g. `gh pr checks`, `git add -p`). Indicates the content should simply be deleted.

## Step 5: Assess Triggering Risk (skills only)

If the target is a `SKILL.md` (user-invocable, not a command), assess the unwanted triggering risk:

- **Low** — Trigger phrases are specific to the domain. Claude won't fire this for unrelated requests.
- **Moderate** — Some trigger phrases are generic enough to fire on unrelated work. The skill gates on a codebase check (e.g. presence of a config file) but still loads context before that check.
- **High** — Trigger phrases are among the most common things any developer says to Claude (e.g. "run my service", "how do I test", "deploy this"). Will fire constantly on non-target codebases.

## Step 6: Write the Assessment

Output the assessment in this exact format:

---

### `<skill-name>`

**Files:** <count> | **Lines:** <breakdown by file>
**Depends on:** <other skills or tools this depends on, if any>

**What it does:** When a user wants to [end-user goal], this [skill/command] [one paragraph describing what it actually does, from the user's perspective. What would make someone invoke it?]

**Unwanted triggering risk:** [Low / Moderate / High]. [One sentence explanation. Only include for skills, not commands.]

**Assessment:** [Delete / Aggressively Trim / Phase Out / Keep]. [2-4 sentences: what is the genuine value (if any), what is bloat, why this verdict. If Aggressively Trim, end with: "**Trimmed form (~N lines):** [what survives]."]

**Underlying issues:**

- **[CLI Stopgap / Doc Stopgap / Process Stopgap / Not an Issue]:** [Specific gap. What would need to exist for this skill to be unnecessary?]
- (repeat for each issue)

---

## Notes

- Be willing to recommend Delete or Phase Out. Most skills should not exist in their current form.
- "The skill is the only documentation" is a Doc Stopgap, not a reason to Keep.
- "The CLI doesn't have this subcommand" is a CLI Stopgap, not a reason to Keep.
- A skill is only genuinely Keep if it requires LLM judgment that no tool or doc can replace.
- Aggressively Trim is appropriate when the constraints are real but the surrounding content is boilerplate. State exactly what survives in the trimmed form.
- Do not conflate "useful information" with "information that belongs in a skill". Useful information belongs in `--help`, READMEs, or godoc. Skills are for orchestration and judgment, not documentation.
