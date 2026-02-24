---
description: Analyze code and suggest refactoring improvements with concrete before/after examples
---

# Refactor

Analyze the specified code and suggest refactoring improvements. Focus on practical changes that reduce complexity and improve maintainability.

## Analysis Checklist

### Code Smells
- Long methods or functions (>30 lines)
- Deep nesting (>3 levels)
- Duplicated logic across files
- God classes or modules doing too much
- Primitive obsession (raw strings/ints where types would help)

### Design Patterns
- Identify where patterns could simplify the code
- Suggest extractions: method, class, interface, module
- Recommend inversions of control where appropriate

### Naming and Structure
- Unclear or misleading names
- Inconsistent naming conventions
- Poor file/module organization

## Output Format

For each suggestion:

1. **What**: Describe the refactoring in one sentence
2. **Why**: What problem does it solve (complexity, duplication, readability)
3. **Before**: Show the current code snippet
4. **After**: Show the refactored version
5. **Risk**: Note any behavioral changes or risks

Prioritize suggestions by impact. Start with the highest-value, lowest-risk changes.

If `$ARGUMENTS` is provided, focus refactoring analysis on those specific files or areas.
