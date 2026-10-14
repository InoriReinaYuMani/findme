# diff-tour setup for FindMe

This adds a code-change guided review tool to FindMe. It does **not** change the iOS app or install anything on your Mac automatically.

## macOS 12 Monterey (recommended: GitHub Codespaces)

The upstream diff-tour v0.3.0 is built with Go 1.27.2, whose supported macOS floor is macOS 13. For Monterey, use a Linux Codespace rather than assuming the binary works locally.

1. In GitHub, open this branch of `InoriReinaYuMani/findme`.
2. Choose **Code → Codespaces → Create codespace on chore/diff-tour-codespaces**.
3. The devcontainer runs `bash scripts/setup-diff-tour.sh`. Confirm with `~/.local/bin/tour --version`.
4. Install and authenticate **one** supported AI CLI in the Codespace: Claude Code, Codex CLI, or Gemini CLI. For example, if Codex is available, run `codex login`. The CLI and its login must live inside the Codespace; local Mac credentials are not shared automatically.
5. Run `tour setup` to select **Japanese** and the authenticated provider.
6. To tour a commit in the current repository run `tour HEAD`. To compare a feature branch to main run `tour main..HEAD` once the feature branch has relevant changes. Alternatively, run `tour` and choose from the interactive list.

**Important:** The tool sends tracked repository content, diffs and commit messages to the selected AI provider to explain the changes. Review secrets and confidential content before using. In Codespaces, the AI provider still needs authentication; diff-tour does not include AI usage credits. Codespaces may incur charges. GitHub Codespaces cannot run Xcode/iOS Simulator: keep your existing Mac/Xcode development setup for builds, and use Codespaces only for guided reviews.

## macOS 13+ or Linux local install

```bash
bash scripts/setup-diff-tour.sh
export PATH="$HOME/.local/bin:$PATH"
tour --version
tour setup
tour HEAD
```

The installer pins diff-tour v0.3.0 and verifies its SHA-256 against the published GitHub release asset digest. It deliberately refuses macOS 12. It does not modify shell startup files, and requires `curl`, `tar`, and a SHA-256 tool.

## Token usage

diff-tour is not a per-prompt token-cost tracker. For that, record usage from the selected AI CLI separately. ChatGPT's chat token counts are not exposed through this tool.

## Troubleshooting

- `tour: command not found`: run `export PATH="$HOME/.local/bin:$PATH"` or use `~/.local/bin/tour`.
- Provider missing: install and log in to Claude Code/Codex CLI/Gemini CLI in the **same** environment as tour.
- No diff to tour: use `tour HEAD` for a committed change or create a feature branch and compare it to main.
- macOS 12 error: use Codespaces, or upgrade macOS before trying local install.
- Codespace CLI flags incompatible: upstream diff-tour is new; check its current README and Issues.
