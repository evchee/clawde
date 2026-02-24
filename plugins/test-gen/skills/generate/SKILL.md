---
description: Generate comprehensive test suites with edge cases, mocks, and good coverage
---

# Test Generator

Generate a comprehensive test suite for the specified code. Follow these guidelines:

## Test Strategy
1. **Detect the testing framework** already used in the project (Jest, pytest, Go testing, etc.). If none exists, pick the most common one for the language.
2. **Read the code under test** thoroughly before writing any tests.
3. **Follow existing test patterns** in the codebase for consistency.

## Test Categories

### Happy Path
- Test the primary use case with valid inputs
- Verify expected outputs and side effects

### Edge Cases
- Empty inputs, zero values, nil/null
- Boundary values (min, max, off-by-one)
- Large inputs and performance-sensitive paths

### Error Handling
- Invalid inputs that should produce errors
- Network/IO failures if applicable
- Timeout and cancellation scenarios

### Integration Points
- Mock external dependencies appropriately
- Test interactions between components
- Verify correct API contract usage

## Output Format
- Write tests in the same language as the code under test
- Use descriptive test names that explain the scenario
- Group related tests logically
- Include setup/teardown where needed
- Add comments explaining non-obvious test logic

If `$ARGUMENTS` is provided, generate tests for those specific files or functions.
