#!/usr/bin/env bash
set -euo pipefail

BASE_REF="${1:-}"
HEAD_REF="${2:-}"
OUT_DIR="${3:-.github/tmp/uk-sync}"

if [[ -z "$BASE_REF" || -z "$HEAD_REF" ]]; then
  echo "Usage: $0 <base-ref> <head-ref> [out-dir]" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

STATUS_FILE="$OUT_DIR/changed_english_status.tsv"
CHANGED_ENGLISH_FILE="$OUT_DIR/changed_english.txt"
MAPPED_UK_FILE="$OUT_DIR/mapped_uk.txt"
MISSING_UK_FILE="$OUT_DIR/missing_uk.txt"
DELETED_ENGLISH_FILE="$OUT_DIR/deleted_english.txt"
STALE_UK_FILE="$OUT_DIR/stale_uk_candidates.txt"
SUMMARY_FILE="$OUT_DIR/summary.md"

: > "$STATUS_FILE"
: > "$CHANGED_ENGLISH_FILE"
: > "$MAPPED_UK_FILE"
: > "$MISSING_UK_FILE"
: > "$DELETED_ENGLISH_FILE"
: > "$STALE_UK_FILE"

while IFS=$'\t' read -r status path1 path2; do
  [[ -z "$status" ]] && continue

  if [[ "$status" == R* ]]; then
    path="$path2"
    previous_path="$path1"
  else
    path="$path1"
    previous_path=""
  fi

  [[ "$path" != guides/source/* ]] && continue
  [[ "$path" == guides/source/uk/* ]] && continue

  printf '%s\t%s\t%s\n' "$status" "$path" "$previous_path" >> "$STATUS_FILE"
done < <(git diff --name-status --find-renames "$BASE_REF" "$HEAD_REF" -- guides/source)

if [[ -s "$STATUS_FILE" ]]; then
  cut -f2 "$STATUS_FILE" | sort -u > "$CHANGED_ENGLISH_FILE"
  awk -F'\t' '$1 !~ /^D/ { path = $2; sub("^guides/source/", "guides/source/uk/", path); print path }' "$STATUS_FILE" | sort -u > "$MAPPED_UK_FILE"
  awk -F'\t' '$1 ~ /^D/ { print $2 }' "$STATUS_FILE" | sort -u > "$DELETED_ENGLISH_FILE"
fi

if [[ -s "$MAPPED_UK_FILE" ]]; then
  while IFS= read -r uk_file; do
    [[ -z "$uk_file" ]] && continue
    if [[ ! -f "$uk_file" ]]; then
      printf '%s\n' "$uk_file" >> "$MISSING_UK_FILE"
    fi
  done < "$MAPPED_UK_FILE"
fi

if [[ -s "$DELETED_ENGLISH_FILE" ]]; then
  while IFS= read -r english_file; do
    [[ -z "$english_file" ]] && continue
    uk_candidate="${english_file/guides\/source\//guides/source/uk/}"
    if [[ -f "$uk_candidate" ]]; then
      printf '%s\n' "$uk_candidate" >> "$STALE_UK_FILE"
    fi
  done < "$DELETED_ENGLISH_FILE"
fi

changed_count="$(wc -l < "$CHANGED_ENGLISH_FILE" | tr -d ' ')"
mapped_count="$(wc -l < "$MAPPED_UK_FILE" | tr -d ' ')"
missing_count="$(wc -l < "$MISSING_UK_FILE" | tr -d ' ')"
deleted_count="$(wc -l < "$DELETED_ENGLISH_FILE" | tr -d ' ')"
stale_count="$(wc -l < "$STALE_UK_FILE" | tr -d ' ')"

{
  echo "## Upstream Rails Guides Sync (Ukrainian)"
  echo
  echo "- Base ref: \`$BASE_REF\`"
  echo "- Head ref: \`$HEAD_REF\`"
  echo "- Changed English guide files: **$changed_count**"
  echo "- Expected Ukrainian files to review: **$mapped_count**"
  echo "- Missing Ukrainian files: **$missing_count**"
  echo "- Deleted English files upstream: **$deleted_count**"
  echo "- Existing Ukrainian files for deleted English pages: **$stale_count**"
  echo
  echo "### Review Checklist"
  echo
  echo "- [ ] Review all changed English files"
  echo "- [ ] Update corresponding Ukrainian files under \`guides/source/uk\`"
  echo "- [ ] Resolve missing Ukrainian files listed below"
  echo "- [ ] Decide whether stale Ukrainian files should be removed"
  echo "- [ ] Run validation and generation locally"
  echo "  - \`BUNDLE_ONLY=default:doc bundle exec rake guides:generate GUIDES_LANGUAGE=uk GUIDES_LINT=1 ALL=1\`"
  echo "  - \`BUNDLE_ONLY=default:doc bundle exec rake guides:generate:html GUIDES_LANGUAGE=uk ALL=1\`"
  echo
  echo "### Changed English Files"
  echo
  if [[ -s "$STATUS_FILE" ]]; then
    while IFS=$'\t' read -r status current_path previous_path; do
      if [[ "$status" == R* ]]; then
        echo "- \`$status\` \`$previous_path\` -> \`$current_path\`"
      else
        echo "- \`$status\` \`$current_path\`"
      fi
    done < "$STATUS_FILE"
  else
    echo "- None"
  fi

  echo
  echo "### Missing Ukrainian Files"
  echo
  if [[ -s "$MISSING_UK_FILE" ]]; then
    sed 's/^/- `/' "$MISSING_UK_FILE" | sed 's/$/`/'
  else
    echo "- None"
  fi

  echo
  echo "### Stale Ukrainian File Candidates"
  echo
  if [[ -s "$STALE_UK_FILE" ]]; then
    sed 's/^/- `/' "$STALE_UK_FILE" | sed 's/$/`/'
  else
    echo "- None"
  fi
} > "$SUMMARY_FILE"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "changed_count=$changed_count" >> "$GITHUB_OUTPUT"
  echo "mapped_count=$mapped_count" >> "$GITHUB_OUTPUT"
  echo "missing_count=$missing_count" >> "$GITHUB_OUTPUT"
  echo "deleted_count=$deleted_count" >> "$GITHUB_OUTPUT"
  echo "stale_count=$stale_count" >> "$GITHUB_OUTPUT"
  echo "summary_file=$SUMMARY_FILE" >> "$GITHUB_OUTPUT"
fi

echo "Delta summary created at $SUMMARY_FILE"
