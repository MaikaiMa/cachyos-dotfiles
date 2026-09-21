# ADR-0012: Use GNOME Keyring and 1Password for secrets

- Status: Accepted
- Date: 2026-09-21

## Context

Coming from macOS, the expectation is a single keychain that stores
application tokens, SSH keys, and signs commits. Linux splits that role
across several services, and this machine already had the pieces without
them being managed or connected.

GNOME Keyring was already started and unlocked by PAM at login and held
GNOME Online Accounts tokens and the `gh` credential helper's token (see
`dot_gitconfig`). The 1Password app already ran its own SSH agent. Neither
was wired into the rest of the session:

- `SSH_AUTH_SOCK` pointed at the 1Password agent only inside interactive
  shells, so GUI applications and other systemd user services did not see
  it.
- `~/.ssh/config` existed on the live machine but was not managed, so a
  fresh machine would not reproduce it.
- Git commits were unsigned; there was no equivalent of macOS's automatic
  keychain-backed commit signing.
- "Integrate with 1Password CLI" was off, so `op` could not be used from a
  terminal.

## Decision

Keep GNOME Keyring as the only Secret Service (`org.freedesktop.secrets`)
provider. It is already started by `pam_gnome_keyring.so` in
`/etc/pam.d/sddm` and unlocked with the login password; nothing new needs to
be managed for it.

Keep the 1Password app's SSH agent as the only SSH agent, and export its
socket for the whole systemd user session with a managed
`environment.d/10-ssh-agent.conf`, instead of relying on shell-only exports.
Point every host at it from a managed `~/.ssh/config`.

Sign Git commits and tags with the SSH key already held in 1Password, using
`op-ssh-sign` as the SSH signing program. Manage the signing configuration in
`dot_gitconfig` and the verification principal in a committed
`allowed_signers` file. Git identity (`user.name`, `user.email`) stays out of
scope and remains configured per repository, as documented in the README.

Use the 1Password CLI (`op`) for ad hoc terminal secrets and scripts that
need a value without writing it to disk, enabled through the app's Developer
settings rather than a managed config file.

## Consequences

- Commits show as "Verified" on GitHub only after the same public key is
  registered there as a **Signing key**, a one-time manual step; the
  existing authentication key entry does not cover signing.
- The first SSH signature per session prompts for authorization in
  1Password; a commit fails if that prompt is dismissed or 1Password is
  locked.
- The SSH agent socket becomes session-wide only after the next login, or
  immediately for services started after a `systemctl --user daemon-reload`.
- The public signing key is committed to this repository; this is
  intentional, matches how `allowed_signers` and GitHub already expect a
  public key, and never exposes the private key, which stays in 1Password.
- No GPG keyring needs to be generated, backed up, or rotated.
- `pam_kwallet5.so` remains present but unused in `/etc/pam.d/sddm`; removing
  it is out of scope for this decision.

## Alternatives considered

- **GPG commit signing:** the more common default, but adds a second key
  type to generate, back up, and rotate outside 1Password.
- **`gcr-ssh-agent` or plain OpenSSH `ssh-agent`:** would keep keys on disk
  or require re-adding them every session instead of reusing 1Password's
  vault-backed agent.
- **KWallet:** the other Secret Service provider available in `sddm`'s PAM
  stack, but it targets KDE applications; this session already standardized
  on GNOME Keyring for existing integrations (GNOME Online Accounts, `gh`).
- **Store the signing key outside the repository:** the key is public by
  design, so hiding it would only add friction without protecting anything.
