# Releasing

Releases are published to [pub.dev](https://pub.dev/packages/nova_editor) by
GitHub Actions using pub.dev's OIDC "automated publishing", so no long-lived
credentials live in this repository.

## One-time setup (already done)

On <https://pub.dev/packages/nova_editor/admin>:

- Automated publishing is enabled for GitHub Actions.
- Repository: `Tayeb-Ali/nova_editor`.
- Tag pattern: `v{{version}}`.
- GitHub Actions environment required: `pub.dev`.

The matching workflow is [`.github/workflows/publish.yml`](.github/workflows/publish.yml).
If you enable environment protection rules on GitHub
(`Settings → Environments → pub.dev`), add required reviewers there; publishing
will then wait for an approval before it starts.

## Publishing a new version

1. Bump `version` in `pubspec.yaml` following [semver](https://dart.dev/tools/pub/versioning).
   Published versions are immutable and cannot be reused.
2. Add the same version and its changes to `CHANGELOG.md`.
3. Verify the package locally:

   ```sh
   dart format .
   flutter analyze
   flutter test
   dart pub publish --dry-run   # must end with "0 warnings"
   ```

4. Commit and tag:

   ```sh
   git add -A
   git commit -m "Release 0.2.0"
   git tag v0.2.0
   git push origin main
   git push origin v0.2.0
   ```

5. The **Publish to pub.dev** workflow runs for the tag. If the `pub.dev`
   environment has required reviewers, approve it in
   <https://github.com/Tayeb-Ali/nova_editor/actions>.
6. Check <https://pub.dev/packages/nova_editor> (analysis can take a few
   minutes) and the package's audit log.

To re-run a publish without creating a new tag, open **Actions → Publish to
pub.dev → Run workflow** (automated publishing is configured to accept
`workflow_dispatch` too). The version in `pubspec.yaml` is what gets published;
if it already exists, bump it first.

## Keeping Nova in sync

Nova consumes this package through a path dependency
(`packages/nova_editor` in the Nova monorepo). After a release, either copy the
package back into that directory, or switch Nova to the hosted package:

```yaml
dependencies:
  nova_editor: ^0.2.0
```

and delete the local copy. Until then, make code changes here first, release,
then mirror them into the monorepo.

## If a release fails

- **Version already exists**: bump `version` and tag again.
- **Artifact hash mismatch between the tag and pub.dev**: the tag must point at
  the commit whose `pubspec.yaml` version is being published.
- **OIDC rejected**: confirm the workflow was triggered by a matching tag, the
  repository and tag pattern on pub.dev, and that the job uses
  `environment: pub.dev`.
