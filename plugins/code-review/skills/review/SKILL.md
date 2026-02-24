---
description: Review code for bugs, security vulnerabilities, performance issues, and best practices
---

# Code Review

Review the provided code or recent changes thoroughly. Check for:

## Bug Detection
- Off-by-one errors, null/undefined access, race conditions
- Incorrect error handling or missing edge cases
- Logic errors and incorrect assumptions

## Security
- Injection vulnerabilities (SQL, XSS, command injection)
- Authentication and authorization issues
- Sensitive data exposure or insecure defaults
- OWASP Top 10 concerns

## Performance
- Unnecessary allocations or copies
- N+1 query patterns
- Missing caching opportunities
- Algorithmic complexity concerns

## Code Quality
- Naming clarity and consistency
- Function length and single-responsibility
- Dead code or unused imports
- Missing or misleading comments

Format your review as a list of findings, each with:
- **Severity**: critical / warning / suggestion
- **Location**: file and line reference
- **Issue**: what's wrong
- **Fix**: concrete suggestion

If `$ARGUMENTS` is provided, focus the review on those specific files or concerns.
