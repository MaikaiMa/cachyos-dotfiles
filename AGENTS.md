# Working agreements

This repository is the source of truth for user-level configuration on CachyOS
with Niri.  It deliberately does not represent the live home directory.

## Change discipline

- Inspect `git status` before editing. Preserve unrelated and user-owned
  changes, and stop when the worktree contains unexpected modifications.
- Make small, focused changes. Inspect the relevant files before editing them
  and do not reformat or modify unrelated configuration.
- Treat `chezmoi/` as the chezmoi source directory. Add managed files there,
  never by editing their live counterparts under `$HOME`.
- Keep implementation, package manifests, tests, and user documentation in
  sync. Follow the shared completion checklist in `docs/maintenance.md`.
- Scripts must be idempotent, use POSIX `sh` unless Bash is genuinely needed,
  and fail clearly when a prerequisite is absent.
- Fish is the user's interactive shell. Every command intended for the user to
  paste into a terminal, including commands in assistant responses, must be
  valid Fish syntax. Mark copyable documentation blocks as `fish` and validate
  them with `tests/fish-docs.sh`. Put multi-step operational logic in an
  executable POSIX `sh` script with a shebang, then show only the script
  invocation; never present POSIX assignments such as `name=value` as commands
  to paste into Fish.
- Prefer official Arch/CachyOS packages. Record them in
  `packages/pacman.txt`; record unavoidable AUR packages separately in
  `packages/aur.txt` with a short rationale.
- Never commit secrets, private keys, tokens, Wi-Fi profiles, host-specific
  identifiers, or other personal machine data. Use documented placeholders
  where needed.
- Run `shellcheck` and `shfmt -d` on every changed POSIX shell script. Run
  `fish -n` on changed Fish scripts and `tests/validate.sh` before handing off
  a structural change.
- Add an ADR in `docs/adr/` before adopting a system-wide architectural
  decision. Do not silently introduce such decisions in scripts or configs.
- A change to the Niri `input`, `output`, `cursor`, or `debug` sections
  (`chezmoi/dot_config/niri/cfg/input.kdl`, `misc.kdl`, `display.kdl`) also
  changes what the login screen needs: the greeter runs its own Niri from a
  copy of those sections. State in the handoff that the user must run
  `./scripts/setup-greetd.sh` after applying such a change; see
  `docs/greeter.md`.

## Validation and handoff

- Validation must report required files that are not yet tracked by Git. They
  must be included in the final diff and tracked before committing.
- Before handing off a change, run `git diff --check`,
  `tests/validate.sh`, and a real-home `scripts/bootstrap.sh --dry-run`.
- Review the complete dry-run output and report which live or system files
  would be added, changed, or removed. A dry-run must not install packages,
  modify system files, or apply chezmoi.
- Summarize changed files, test results, dry-run results, remaining risks, and
  any checks that still require the user's machine.

## Boundaries

- Do not install packages, apply chezmoi, enable services, or edit live Niri
  configuration unless the user explicitly asks.
- Do not commit or push changes unless the user explicitly asks. Leave the
  final diff available for user review.
- Keep generated files and machine-local state out of Git.
