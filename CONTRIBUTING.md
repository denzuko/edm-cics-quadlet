# Contributing

## Workflow (BDD-first)
1. Open GitHub Issue
2. Branch: feat/N or fix/N
3. Write BATS test first — never write implementation before the test exists and fails
4. Write code until tests pass
5. Run shellcheck (shell repos)
6. Update CHANGELOG.md under [Unreleased]
7. Push → PR → review → merge → semver tag

Never commit directly to main/master. BDD order is mandatory.

## Semver
- MAJOR — breaking interface change
- MINOR — new non-breaking capability
- PATCH — everything else; freely exceeds 100
