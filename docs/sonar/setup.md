# SonarCloud setup

- Import/bind `ManuelSelch/pi-studio` in SonarQube Cloud's EU region and select GitHub Actions (CI-based analysis). Disable automatic analysis if enabled.
- Ensure the organization has private-project entitlement and that the token can analyze this project.
- Configure repository Actions variables `SONAR_ORGANIZATION=manuelselch` and `SONAR_PROJECT_KEY=ManuelSelch_pi-studio` (adjust if the imported project uses different identifiers).
- Configure repository Actions secret `SONAR_TOKEN` with an authorized analysis token. Never commit the token. Existing secrets in other repositories are not automatically inherited.

The `sonar` job runs after all three existing CI jobs succeed. It skips fork PRs, fails with setup guidance when configuration is missing, and waits for the quality gate. Gate failure fails CI; required merge checks must be configured separately if desired.

## Coverage

The package job runs PiUI tests with SwiftPM coverage enabled. LLVM exports LCOV, then `scripts/sonar-coverage.py` converts production PiUI line counts to generic Sonar XML. Repository-relative file paths allow the macOS-generated artifact to be imported on Ubuntu. Tests, fetched dependencies and generated output are excluded. Duplicate line records merge by covered status; branch coverage is not reported.

Native iOS test/UI coverage is not imported. Native app-shell code remains analyzed and included in coverage metrics without imported hits. No native macOS automation is enabled. Existing gate thresholds are not weakened.

Local commands:

```sh
python3 scripts/test-sonar-coverage.py
PI_STUDIO_COVERAGE=1 bash scripts/test-package.sh
```

Reports are ignored under `.build/coverage/`; CI retains the XML artifact for seven days. Empty PiUI coverage fails conversion. Default local package tests remain uninstrumented.

An authorized push/PR and successful hosted analysis are needed to verify credentials, private-project access, project binding and quality-gate results. Repository configuration alone does not prove these.
