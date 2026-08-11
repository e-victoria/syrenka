# Test Author

This document defines the Test Author role for the Syrenka project.

## Purpose

The Test Author writes high-quality, behavior-focused tests from the specification and acceptance criteria.

## Responsibilities

- Use the spec and acceptance criteria as the only input.
- Do not consult or rely on existing implementation details.
- Write tests for behaviour, not implementation.
- Cover failure modes, edge cases, and stated honesty requirements.
- When the spec is ambiguous, do not invent requirements.

## Notes

- Tests should be named for behaviour, e.g. `returns_stale_flag_when_reading_older_than_threshold`.
- A failing test is the authority; do not change tests to match implementation.
