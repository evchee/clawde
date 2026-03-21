---
name: judge-skill
description: "Analyse a Claude Code skill or command. Understand what it does and gather nuance (migration tool? LLM-heavy?), decompose into underlying issues, classify each (CLI Stopgap / Doc Stopgap / Process Stopgap / Justified / Temporary / Unnecessary), then produce a structured assessment with verdict (Delete / Trim / Phase Out / Keep) in the standard format."
---

# Judge Skill

Analyse a Claude Code skill or command using the stopgap skill framework.

## Arguments

`$ARGUMENTS`: skill name, path, or `plugin/skill` reference (e.g. `rapid`, `atlas:go-test`, `datadog-claude-plugins/dd/skills/conductor`). Ask if not provided.

---

## Phase 1: Read Everything

Locate the skill. Check in order:
1. Path given in `$ARGUMENTS`
2. `~/.claude/plugins/marketplaces/*/skills/$ARGUMENTS/`
3. `~/.claude/plugins/cache/*/skills/$ARGUMENTS/`
4. `~/evchee/clawde/plugin/skills/$ARGUMENTS/` or `~/evchee/clawde/plugin/commands/$ARGUMENTS/`

Read **every file**: SKILL.md or COMMAND.md, all companion docs, all scripts, all examples, all sub-agent definitions. Record file count and total line count per file.

---

## Phase 2: Understand What It Does and Gather Nuance

Before classifying anything, answer:

**What is it for?**
- What end-user goal triggers this? What would make someone invoke it?
- Is it a skill (auto-triggered by keywords) or a command (explicitly invoked)?

**What kind of tool is it?**
- Is it a **one-time or migration tool**? Will it be retired when the work is complete?
- Is it domain-specific or broadly applicable?
- Does it wrap a single CLI or coordinate multiple systems?

**What does it actually contain?**
- How much is step-by-step tutorial vs. constraint documentation vs. code generation vs. orchestration?
- What do companion docs, scripts, and sub-agents each do?
- How large is it relative to what it actually needs to say?

**Triggering risk** (skills only):
- What are the trigger phrases? Are they generic ("run my service", "how do I test") or specific?
- Would the user always invoke this explicitly, or could it fire on unrelated requests?
- If triggers are high-risk and invocation is always explicit → should be a command, not a skill.

---

## Phase 3: Research Ground Truth

Phase 2 established *what* the skill claims. This phase checks *whether those claims add value* by verifying them against authoritative sources.

For each CLI tool the skill mentions:
- Run `<tool> --help` and `<tool> <subcommand> --help` — does what the skill documents actually exist?
- Search the codebase: do documented subcommands/flags exist in source?
- For each constraint or gotcha: is it in `--help`? In a README? Derivable by reading existing code patterns in the repo?
- For each error table entry: does a `doctor` or `validate` command already auto-diagnose this?

Distinguish clearly:
- **Invented knowledge** — not derivable from any tool, code, or existing examples
- **Duplicated knowledge** — already in `--help`, README, or inferrable from existing patterns

---

## Phase 4: Decompose Into Underlying Issues

List every distinct thing the skill does or compensates for. For each one, ask: **why does this need to be in a skill?**

Classify each with exactly one label. For each stopgap, state what would need to exist for the skill to no longer need to address it.

**CLI Stopgap** — A command, subcommand, flag, or validation rule missing from the CLI.

  Feasibility notes — assess before labelling:
  - *One-time/migration tool*: Gap in a tool that will be retired → label **Temporary** instead (low ROI to fix; the tool will go away).
  - *LLM judgment mixed in*: If a CLI could handle 70% but 30% still needs LLM interpretation, the deterministic part is CLI Stopgap but the judgment part make it **Justified**. 
  - *Multi-repo*: Requires write access across multiple repositories → label **Justified**. Coordinating changes across repo boundaries requires contextual judgment a CLI cannot encode easily a this time.
  - *Multi-team*: Requires coordination across teams with different owners → label **Process Stopgap**. This is an ownership/workflow gap, not a technical one.
  - *Missing installation*: "Command not found" is an installation/onboarding problem, not a feature gap. Label as **Doc Stopgap** if install docs are missing, or **Unnecessary** if the LLM can figure it out with the docs that exist.
  - *Partial scaffold (inline)*: A scaffold that inserts code at arbitrary call sites in existing files (not whole-file generation) is **Justified** — insertion point selection and surrounding context require LLM judgment. A scaffold that generates new whole files from existing metadata (routes, schema) is a CLI Stopgap.

**Doc Stopgap** — Information missing from `--help`, README, godoc, or SDK docs. The skill substitutes for missing documentation.

  Note: Static tribal knowledge (always the same answer regardless of codebase state) is a Doc Stopgap. If the knowledge requires reasoning over the specific codebase context at invocation time, it is **Justified**.

**Process Stopgap** — Coordination or ownership gap spanning multiple teams or systems. No single tool owns the fix.

**Justified** — A skill/LLM approach is the right solution. The task requires contextual judgment, codebase analysis, or interpretation that no deterministic tool can replicate. Building a CLI would not remove the need for LLM involvement.

**Temporary** — A real gap (CLI, doc, or process) in a tool or workflow that will be retired once a migration or one-time task completes. Could have been classified as a stopgap, but fixing it is low ROI because the issue is going away.

**Unnecessary** — The LLM handles this organically. Claude already knows this natively (standard Git, standard `gh` commands), or the concern being addressed is not real.

---

## Phase 5: Determine Verdict

With the decomposed issue list in hand, choose one verdict. If multiple seem to fit, use these rules:

**Delete** — Every underlying issue is Unnecessary, or already addressed by existing tools. No remaining value.

**Phase Out** — All genuine issues are stopgaps (CLI/Doc/Process/Temporary). The skill is correct to exist today but should be deleted once those gaps are fixed. Prefer Phase Out over Trim when all the value is stopgap — trimming something you plan to delete is wasted effort. State the specific condition that triggers deletion.

**Trim** — Some issues are Justified or involve genuinely non-obvious constraints (tribal knowledge, silent failures, misleading errors), but the genuine content is buried in boilerplate, examples, or `--help` redocumentation. State exactly which sections survive (by description, not by rewriting them). Applies when there is a mix of Justified/permanent value alongside bloat.

**Keep** — Core value is Justified: genuine LLM judgment, orchestration, or tribal knowledge that no tool or doc can replace. Minor trimming only. 

---

## Phase 6: Write the Output

### `<skill-name>`

**Files:** `<count>` files | **Lines:** `<file1>: N, file2: N, ...`
**Depends on:** `<other skills or tools — omit if none>`

**What it does:** When a user wants to [end-user goal], this [skill/command] [one paragraph from the user's perspective — what would make someone invoke it?]

**Unwanted triggering risk:** [Low / Moderate / High]. [One sentence. Skills only — omit for commands.]

**Assessment:** [Delete / Trim / Phase Out / Keep]. [As many sentences as needed. Cover: genuine value if any, what is bloat, why this verdict.
- If Trim: end with "**Trimmed form (~N lines):** [describe by section what survives — e.g. 'constraints section minus examples, plus error table'. Do not rewrite the content.]"
- If Phase Out: end with the specific condition that triggers deletion.
- If Delete: if the tool's existence is non-obvious, note that a one-line AGENTS.md entry may be appropriate.]

**Underlying issues:**

List issues grouped by label (CLI Stopgap first, then Doc, Process, Justified, Temporary, Unnecessary). Within each group, most impactful first.

- **[label]:** [As many sentences as needed. For stopgaps: what would need to exist and any nuance about feasibility? For Justified: why LLM is the right approach and what judgment is required? For Unnecessary: why the LLM handles it organically? For Temporary: what triggers retirement of the tool?]

---

## Notes

- Be willing to recommend Delete or Phase Out. Most skills should not exist in their current form.
- "The skill is the only documentation" → **Doc Stopgap**, not a reason to Keep.
- "The CLI doesn't have this subcommand" → **CLI Stopgap**, not a reason to Keep. Assess whether it is actually worth building.
- A skill is **Keep** only if LLM judgment is the core value and no tool or doc can replace it.
- Skills where the user would always invoke explicitly → recommend converting to a command.
- Do not conflate "useful information" with "information that belongs in a skill". Useful information belongs in `--help`, READMEs, or godoc.
