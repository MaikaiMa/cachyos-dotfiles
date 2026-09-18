# Working agreements

This repository is the source of truth for user-level configuration on CachyOS
with Niri.  It deliberately does not represent the live home directory.

## Change discipline

- Make small, focused changes. Inspect the relevant files before editing them
  and do not reformat or modify unrelated configuration.
- Treat `chezmoi/` as the chezmoi source directory. Add managed files there,
  never by editing their live counterparts under `$HOME`.
- Scripts must be idempotent, use POSIX `sh` unless Bash is genuinely needed,
  and fail clearly when a prerequisite is absent.
- Prefer official Arch/CachyOS packages. Record them in
  `packages/pacman.txt`; record unavoidable AUR packages separately in
  `packages/aur.txt` with a short rationale.
- Never commit secrets, private keys, tokens, Wi-Fi profiles, host-specific
  identifiers, or other personal machine data. Use documented placeholders
  where needed.
- Run `shellcheck` and `shfmt -d` on every changed shell script. Run
  `tests/validate.sh` before handing off a structural change.
- Add an ADR in `docs/adr/` before adopting a system-wide architectural
  decision. Do not silently introduce such decisions in scripts or configs.

## Boundaries

- Do not install packages, apply chezmoi, enable services, or edit live Niri
  configuration unless the user explicitly asks.
- Keep generated files and machine-local state out of Git.
