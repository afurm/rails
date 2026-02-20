# Translating Rails Guides to Ukrainian

This repository keeps the Ukrainian translation in-repo under `guides/source/uk`.
The source-of-truth for English updates remains `upstream/main` from `rails/rails`.

## Repository Setup

1. Ensure remotes are configured:

```bash
git remote -v
git remote add upstream https://github.com/rails/rails.git # if missing
```

2. Keep `main` in sync with your fork's `origin/main`.

## Local Build Commands

Install docs dependencies:

```bash
BUNDLE_ONLY=default:doc bundle install
```

Lint/render validation for Ukrainian guides:

```bash
cd guides
BUNDLE_ONLY=default:doc bundle exec rake guides:generate GUIDES_LANGUAGE=uk GUIDES_LINT=1 ALL=1
```

Generate Ukrainian HTML:

```bash
cd guides
BUNDLE_ONLY=default:doc bundle exec rake guides:generate:html GUIDES_LANGUAGE=uk ALL=1
```

Generated files are published from `guides/output/uk`.

## Weekly Sync PR Flow

A weekly GitHub Actions workflow (`sync-upstream-guides.yml`) does the following:

1. Fetches `upstream/main`.
2. Merges upstream changes into a sync branch.
3. Runs `.github/scripts/uk_translation_delta.sh`.
4. Opens a PR to `main` with a checklist and file-delta summary.

### How to Review the Sync PR

1. Read the PR checklist and summary.
2. Review changed English files under `guides/source/*`.
3. Update corresponding files under `guides/source/uk/*`.
4. Resolve any "Missing Ukrainian Files" listed in the PR body.
5. Run local Ukrainian lint and generation commands before merging.

## Conflict Resolution Flow

If the scheduled workflow fails during merge:

1. Create a local sync branch from `main`.

```bash
git checkout main
git pull --ff-only origin main
git checkout -b sync/upstream-manual-YYYYMMDD
```

2. Fetch and merge upstream.

```bash
git fetch upstream main
git merge --no-ff upstream/main
```

3. Resolve conflicts, especially under `guides/source/uk`.
4. Run delta script for visibility:

```bash
.github/scripts/uk_translation_delta.sh "$(git merge-base main HEAD)" "$(git rev-parse HEAD)"
```

5. Validate and generate Ukrainian guides locally.
6. Push branch and open PR to `main`.

## Translation Quality Checklist

- Terminology is consistent across files (`guides/source/uk/*.md`).
- Frontmatter and markdown structure are preserved.
- Code examples are not translated unless comments or prose require it.
- Internal links, anchors, and filenames remain valid.
- `documents.yaml` includes all expected pages and URLs.
- Shared templates (`layout.html.erb`, `_welcome.html.erb`, `_license.html.erb`) stay localized.

## Publish Verification

Publishing is automated in `.github/workflows/publish-uk-guides.yml` on pushes to `main`.

After merge:

1. Confirm `Publish Ukrainian Guides` workflow succeeds.
2. Open deployed site URL from workflow output.
3. Smoke-check:
   - `index.html` loads.
   - menu navigation works.
   - assets (CSS/JS/images) load.
   - pages have `lang="uk"` and `og:locale="uk_UA"`.
4. If deployment fails, inspect the build step and rerun after fixes.
