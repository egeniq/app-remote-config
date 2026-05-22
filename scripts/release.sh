#!/usr/bin/env bash
# release.sh — Build, upload, and publish a care binary release
#
# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh 0.7.2
#
# Prerequisites:
#   - gh CLI authenticated
#   - GitHub release for <version> already exists (or pass --create-release)
#   - Homebrew tap checked out at HOMEBREW_TAP_PATH
#
# The script:
#   1. Builds care for arm64 and x86_64
#   2. Creates a universal binary with lipo
#   3. Packages it as care-<version>-macos.tar.gz
#   4. Uploads the archive to the GitHub release
#   5. Updates the homebrew formula with the new URL + SHA256
#   6. Commits and pushes the formula update

set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version>" >&2
    exit 1
fi

REPO="egeniq/app-remote-config"
PRODUCT="care"
ARCHIVE="${PRODUCT}-${VERSION}-macos.tar.gz"
HOMEBREW_TAP_PATH="${HOMEBREW_TAP_PATH:-/Users/jkool/Developer/Egeniq/homebrew-app-utilities}"
FORMULA_PATH="${HOMEBREW_TAP_PATH}/Formula/care.rb"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> Building ${PRODUCT} ${VERSION} for arm64 and x86_64..."
cd "${REPO_ROOT}"

swift build \
    --disable-sandbox \
    -c release \
    --product "${PRODUCT}" \
    --arch arm64

swift build \
    --disable-sandbox \
    -c release \
    --product "${PRODUCT}" \
    --arch x86_64

echo "==> Creating universal binary..."
lipo -create \
    -output ".build/${PRODUCT}" \
    ".build/arm64-apple-macosx/release/${PRODUCT}" \
    ".build/x86_64-apple-macosx/release/${PRODUCT}"

echo "==> Packaging..."
cp ".build/${PRODUCT}" "${PRODUCT}"
tar -czf "${ARCHIVE}" "${PRODUCT}"
rm "${PRODUCT}"

SHA256=$(shasum -a 256 "${ARCHIVE}" | awk '{print $1}')
echo "==> SHA256: ${SHA256}"

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${ARCHIVE}"

echo "==> Uploading ${ARCHIVE} to GitHub release ${VERSION}..."
gh release upload "${VERSION}" "${ARCHIVE}" --clobber --repo "${REPO}"
rm "${ARCHIVE}"

echo "==> Updating formula at ${FORMULA_PATH}..."
ESCAPED_URL="${DOWNLOAD_URL//\//\\/}"

ruby - "${FORMULA_PATH}" "${VERSION}" "${DOWNLOAD_URL}" "${SHA256}" <<'RUBY'
formula_path, version, url, sha256 = ARGV

content = File.read(formula_path)

stable_block = "  url \"#{url}\"\n  sha256 \"#{sha256}\""

if content =~ /stable do.*?end/m
    # Remove stable block, replace with flat url/sha256
    content = content.gsub(/[ \t]*stable do\n.*?\n[ \t]*end\n?/m, "#{stable_block}\n")
elsif content =~ /^\s*url\s+/
    # Update existing flat url/sha256
    content = content.gsub(/^\s*url\s+"[^"]*"\n/, "#{stable_block}\n")
    content = content.gsub(/^\s*sha256\s+"[^"]*"\n/, '')
    content = content.gsub(/^\s*version\s+"[^"]*"\n/, '')
else
    # Migrate from old-style multi-line url + tag/revision to flat url/sha256.
    # Remove url (possibly multi-line), tag:, revision:, sha256, and bare version lines.
    content = content.gsub(/^\s*url\s+"[^"]*".*?\n(?:(?:\s+tag:.*\n)|(?:\s+revision:.*\n))*/m, '')
    content = content.gsub(/^\s*(sha256|revision|tag)\s+.*\n/, '')
    content = content.gsub(/^\s*version\s+"[^"]*"\n/, '')
    # Insert url/sha256 before license/head/depends_on
    content = content.sub(/(^\s*(?:license|head|depends_on))/, "#{stable_block}\n\n\\1")
end

File.write(formula_path, content)
puts "Formula updated."
RUBY

cd "${HOMEBREW_TAP_PATH}"
git --no-pager diff "${FORMULA_PATH}"
git add "${FORMULA_PATH}"
git commit -m "care: update to ${VERSION} with universal binary

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
git push

echo ""
echo "✅ Released ${PRODUCT} ${VERSION}"
echo "   Binary: ${DOWNLOAD_URL}"
echo "   SHA256: ${SHA256}"
