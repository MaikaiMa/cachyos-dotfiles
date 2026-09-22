# Mail

[Hylki](https://hylki.hyprlab.co/) is the managed mail client: a Rust and
libadwaita application with a unified inbox for several accounts. It talks
IMAP and SMTP directly. Proton Mail is reached through the locally running
Proton Mail Bridge; Google accounts authenticate through GNOME Online
Accounts. See [ADR-0010](adr/ADR-0010-adopt-hylki-as-mail-client-via-flatpak.md)
for the choice and the Flatpak exception.

## Installation

Hylki is distributed only as a signed Flatpak from the developer's remote.
Install the runtime dependencies from the official repositories:

```fish
sudo pacman -S --needed flatpak gnome-online-accounts gnome-control-center
```

Then install Hylki as a user Flatpak. The flatpakref adds the `hylki-origin`
remote with its GPG key and pulls the GNOME runtime from Flathub:

```fish
flatpak install --user --from https://hylki.hyprlab.co/flatpak/co.hyprlab.Hylki.flatpakref
```

Flatpak exports desktop entries through `XDG_DATA_DIRS`, which a systemd
environment generator sets for the user session. Processes that were already
running when Flatpak was first installed do not see the new path. Restart the
shell so its launcher lists Hylki, or log out and in:

```fish
dms-reset
```

## Accounts

### Proton Mail through Bridge

`protonmail-bridge.service` runs Bridge non-interactively and is enabled by
the dotfiles. Log in to Bridge once with its CLI before the service is used,
and stop the service while the CLI is open because Bridge runs a single
instance:

```fish
systemctl --user stop protonmail-bridge.service; and protonmail-bridge-core --cli
```

In the CLI, `login` adds the Proton account and `info` prints the generated
Bridge password for mail clients. Leave with `exit`, then start the service
again:

```fish
systemctl --user start protonmail-bridge.service
```

Add the account in Hylki as a generic IMAP account:

| Setting | Value |
| --- | --- |
| IMAP | `127.0.0.1`, port `1143`, STARTTLS |
| SMTP | `127.0.0.1`, port `1025`, STARTTLS |
| Username | the Proton address |
| Password | the Bridge password from `info`, not the Proton password |

Bridge serves a locally signed certificate. Hylki asks once to trust it; the
connection never leaves the machine.

### Google through GNOME Online Accounts

Hylki's official build does not ship a Google OAuth client and imports Google
accounts from GNOME Online Accounts instead. GNOME Settings is the only user
interface that can add such an account. It runs under Niri when it presents
itself as GNOME:

```fish
env XDG_CURRENT_DESKTOP=GNOME gnome-control-center online-accounts
```

Add each Google account there, enable only Mail, then import the accounts in
Hylki's account settings. Tokens are stored in the GNOME keyring, which the
session already runs.

## Shortcuts and defaults

- `Mod3+M` (Caps+M) focuses the existing Hylki window or starts it.
- `Mod3+Shift+M` opens a new message through the `mailto:` handler.
- `mailto:` and `mid:` links open in Hylki through the managed `mimeapps.list`.
- Hylki opens on the `chat` workspace.

## Machine-local state

Hylki keeps account configuration, mail cache, and credentials under
`~/.var/app/co.hyprlab.Hylki/`; Bridge keeps its encrypted vault under
`~/.config/protonmail/bridge-v3/` and its sync cache under
`~/.local/share/protonmail/`. None of this is managed or committed. The
Flatpak sandbox has read access to the home directory for attachments; treat
Hylki as a trusted local application accordingly.
