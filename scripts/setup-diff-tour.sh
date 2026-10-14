#!/usr/bin/env bash
# Install the reviewed diff-tour v0.3.0 release for Linux or macOS 13+.
# This deliberately refuses macOS 12: diff-tour is built using Go 1.27.
set -euo pipefail

version="v0.3.0"
install_dir="${TOUR_INSTALL_DIR:-$HOME/.local/bin}"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "Required: $1" >&2; exit 1; }
}
require curl
require tar
require uname

case "$(uname -s)" in
  Linux) platform="linux" ;;
  Darwin)
    platform="darwin"
    require sw_vers
    mac_major="$(sw_vers -productVersion | cut -d. -f1)"
    if [ "$mac_major" -lt 13 ]; then
      echo "diff-tour v0.3.0 requires macOS 13+ (Go 1.27). Detected macOS $(sw_vers -productVersion)." >&2
      echo "Use the supplied GitHub Codespaces configuration on macOS 12 Monterey." >&2
      exit 2
    fi
    ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

case "$(uname -m)" in
  x86_64|amd64) arch="amd64" ;;
  arm64|aarch64) arch="arm64" ;;
  *) echo "Unsupported CPU: $(uname -m)" >&2; exit 1 ;;
esac

# Independently pinned SHA-256 values from GitHub release v0.3.0.
case "${platform}_${arch}" in
  darwin_amd64) expected="9a1f4585fb82234a36ff5734f85a95ec81c69f37a46bdf85999ed1c1201061eb" ;;
  darwin_arm64) expected="1012379b355d5f9065fe680a9e6a95aaabca76b72a178642e34577f2dceef86c" ;;
  linux_amd64)  expected="2dc11a6212014b246922f9694794a8daf3340b111b47066e735c327f887548fb" ;;
  linux_arm64)  expected="7ccb3ee18d824dd681ecfbe491f626e65a16dfa81ee9d498f2b70e0153ca5896" ;;
  *) echo "No checksum for ${platform}_${arch}" >&2; exit 1 ;;
esac

archive="diff-tour_${version#v}_${platform}_${arch}.tar.gz"
url="https://github.com/init-co-jp/diff-tour/releases/download/${version}/${archive}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo "Downloading ${url}"
curl --fail --location --silent --show-error --retry 3 "$url" -o "$tmp/$archive"

if command -v shasum >/dev/null 2>&1; then
  actual="$(shasum -a 256 "$tmp/$archive" | awk '{print $1}')"
else
  require sha256sum
  actual="$(sha256sum "$tmp/$archive" | awk '{print $1}')"
fi

if [ "$actual" != "$expected" ]; then
  echo "SHA-256 mismatch: refusing to install." >&2
  exit 1
fi

tar -xzf "$tmp/$archive" -C "$tmp" tour
mkdir -p "$install_dir"
install -m 0755 "$tmp/tour" "$install_dir/tour"
echo "Installed ${install_dir}/tour"
"$install_dir/tour" --version

case ":$PATH:" in
  *":$install_dir:"*) ;;
  *)
    echo
    echo "Add this to ~/.zshrc or ~/.bashrc, then open a new terminal:"
    echo 'export PATH="$HOME/.local/bin:$PATH"'
    ;;
esac

echo "Next: run 'tour setup', then 'tour HEAD' inside a Git repository."
