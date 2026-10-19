CI/CD is Xcode Cloud on the personal team (Van Khanh Vu, `W3274W2Y83`); there is no
fastlane and no GitHub Actions. The **Verify** workflow runs on every push to `main` and
every PR: `ci_scripts/ci_post_clone.sh` runs the fast rules in `ci_scripts/app_post_clone.sh`,
then the workflow's Test action builds and tests. **Release** archives and uploads to
TestFlight; it never submits for review. Signing is cloud-managed. `ci_post_clone.sh` and
`ci_post_xcodebuild.sh` are shared across personal apps (source: KVAppKit `xcode-cloud/`);
put app-specific steps in `app_post_clone.sh`. Xcode Cloud does not resolve packages on
its own, so a dependency change must commit `Package.resolved` with it.

