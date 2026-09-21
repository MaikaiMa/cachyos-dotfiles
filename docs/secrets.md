# Secrets

Three layers replace the macOS keychain: [GNOME
Keyring](https://wiki.gnome.org/Projects/GnomeKeyring) as the Secret Service
(`org.freedesktop.secrets`) for application tokens, the 1Password SSH agent
for keys, and 1Password together with its CLI `op` for passwords and
terminal secrets. See [ADR-0012](adr/ADR-0012-use-gnome-keyring-and-1password-for-secrets.md)
for why these three and not one.

## Application secrets

GNOME Keyring is started and unlocked by PAM at login through
`pam_gnome_keyring.so` (`auth` and `session`, with `auto_start`) in
`/etc/pam.d/sddm`, storing its data in `~/.local/share/keyrings/login.keyring`.
It unlocks with the login password, so it changes whenever that does.
GNOME Online Accounts tokens (used by Hylki for Google Mail, see
[docs/mail.md](mail.md)) and the `gh` token used by `dot_gitconfig`'s
credential helper both live here.

Inspect stored secrets from a terminal with `secret-tool` (package
`libsecret`):

```fish
secret-tool search --all xdg:schema org.gnome.OnlineAccounts
```

## SSH

The 1Password SSH agent is enabled in the 1Password app itself; that toggle
is not repository state. `~/.ssh/config` is managed and points every host at
it, and `environment.d/10-ssh-agent.conf` exports `SSH_AUTH_SOCK` for the
whole systemd user session, so GUI applications and other services see the
same agent as an interactive shell. This takes effect at the next login; a
unit started after the file changed can pick it up sooner with
`systemctl --user daemon-reload`.

Verify the agent is reachable and lists a key:

```fish
ssh-add -l
```

## Git commit signing

Commits and tags are signed with the SSH key already held in 1Password,
using `/opt/1Password/op-ssh-sign` as the signing program
(`gpg.format = ssh`, `commit.gpgsign` and `tag.gpgsign` both on). The
committed `allowed_signers` file lets `git log --show-signature` verify
signatures locally without contacting GitHub.

Showing as "Verified" on GitHub needs a one-time step beyond this repository:
add the same public key on GitHub as a **Signing key** (Settings, SSH and
GPG keys, New SSH key, key type "Signing Key"). The authentication key entry
most accounts already have does not make commits verified by itself.

1Password asks for authorization on the first signature of a session; a
commit fails if that prompt is dismissed or 1Password is locked.

Print the public key to compare it with what is registered on GitHub and in
`allowed_signers`:

```fish
ssh-add -L
```

Identity (`user.name`, `user.email`) is deliberately not managed here and
stays configured per repository; the principal in `allowed_signers` is the
GitHub-provided noreply address for that identity, not a personal email.

## 1Password CLI

"Integrate with 1Password CLI" is enabled in the app's Developer settings.
The first use per account needs an explicit sign-in:

```fish
op signin
```

After that, `op read` and `op run` provide secrets to commands without
writing them to disk. Two accounts are configured, so pick one explicitly
rather than relying on whichever is default:

```fish
op signin --account webbio.1password.eu
```

## Machine-local state

Keyring contents, 1Password's own data (`~/.config/1Password`,
`~/.1password`), and the `op` CLI configuration (`~/.config/op`) are
machine-local and never managed or committed. The public signing key
committed in `chezmoi/dot_gitconfig` and `chezmoi/dot_config/git/allowed_signers`
is public by design; the matching private key never leaves 1Password.
