# SolDoKu Merge Gate (P0)

Last updated: 2026-02-25

## Required Checks

- `iOS CI / build-and-test` must pass on every pull request.
- Required check must include:
  - iOS generic device build (Debug + Release)
  - iOS simulator build (Debug + Release)
  - domain unit tests (`swift test`)

## Branch Protection Policy (`main`)

- Direct push to `main` is not allowed.
- Pull request is required before merge.
- At least one approval review is required.
- Dismiss stale approvals when new commits are pushed.
- Require branches to be up to date before merge.

## Merge Blocking Rules

- If required check fails, merge is blocked.
- If required check is missing, merge is blocked.
- If required review count is not met, merge is blocked.

## Owner Checklist

- [x] Repository settings updated with rules above.
- [x] `iOS CI / build-and-test` is marked as required status check.
