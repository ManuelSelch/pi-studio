# SonarCloud CI — Design

## Overview
Add SonarQube Cloud analysis to the existing [CI workflow](../../.github/workflows/ci.yml), following Pi Chat's exclusion-based configuration. Include line coverage from PiUI's SwiftPM tests, converted from LLVM LCOV to Sonar's generic XML. Native iOS tests/builds remain unchanged; their coverage is not imported in this setup.

## Components
| Package/module | Component | Change | Responsibility |
|---|---|---|---|
| CI | [ci.yml](../../.github/workflows/ci.yml) | Changed | Run a dedicated Sonar job after existing package, iOS and macOS jobs succeed |
| Analysis | `sonar-project.properties` (proposed) | New | UTF-8 and exclusions for tests, mockups, dependencies and build output |
| Coverage | `scripts/test-package.sh`, proposed LCOV converter and tests | Changed / New | Opt-in SwiftPM instrumentation, repository-relative generic coverage XML and artifact upload |
| GitHub / SonarCloud | Repository variables, secret and linked project | Configured | Own analysis credentials and project identity, outside source control |

## Runtime flow
1. Existing triggers run current checks; the package job additionally enables Swift coverage, exports LCOV and converts only PiUI production paths into `.build/coverage/sonar.xml`. Empty/missing source coverage fails rather than publishing a misleading report.
2. A dedicated Ubuntu job downloads that artifact and checks out full history with credentials persistence disabled. Fork pull requests skip analysis; existing tests still run.
3. Validate project variables and token presence without printing credentials, then run a commit-pinned official Sonar scan action.
4. Wait up to 300 seconds for the quality gate. Scan or gate failures fail the job; the job has a 15-minute timeout.

## Contracts & API changes
- GitHub → scanner: proposed repository variables `SONAR_ORGANIZATION=manuelselch`, `SONAR_PROJECT_KEY=ManuelSelch_pi-studio`, and Actions secret `SONAR_TOKEN`.
- Scanner → SonarCloud: CI-based analysis for the linked private repository; disable automatic analysis if enabled. Private-project entitlement and project access must be verified during provisioning.
- Package script → converter → scanner: `PI_STUDIO_COVERAGE=1` enables instrumentation/export; LCOV `DA` counts become generic XML line coverage with repository-relative paths so reports transfer between runners. Duplicate line entries merge by covered status. No branch-coverage claims.
- Application APIs and dependencies remain unchanged. Default local package testing remains uninstrumented.

## Decisions & Trade-offs
- Reuse SonarCloud, not the unrelated Sonar MCP endpoint. Organization/key above are proposed defaults, not verified project settings.
- No explicit `sonar.sources` or `sonar.tests`. Exclude `Packages/**/Tests/**`, native test directories, mockups, scripts, documentation, `.build`, `.dependencies` and nested SwiftPM build/checkouts; retain application and PiUI production sources.
- Do not silently skip a trusted scan when configuration is missing: fail with setup guidance. Current repository variable/secret listings are empty; an unauthenticated project lookup cannot establish whether a private Sonar project exists.
- Coverage measures PiUI tests only. Native app-shell code remains analyzed and counted as uncovered without a report; do not exclude it to inflate coverage. No iOS/UI coverage aggregation or native macOS automation is added.
- Leave README unchanged; Sonar setup details stay in dedicated documentation.
- No privileged PR triggers, branch-protection changes, automatic push or native macOS automation.

## Verification
- Planned: converter tests for hit/miss counts, duplicate records, XML escaping, path filtering and empty reports; script opt-in/default behavior checks; actual instrumented PiUI tests and report path validation; actionlint and action commit verification.
- Verify repository configuration names without reading or logging token values. Confirm project binding, CI analysis mode and private-project access with authorized Sonar access.
- A user-authorized push and successful hosted scan are required to verify analysis and quality-gate behavior; local checks cannot establish either.

## Open Questions
None. User approved implementation with coverage; README must remain unchanged.
