# ADR-0010: Adopt Hylki as mail client via Flatpak

- Status: Accepted
- Date: 2026-09-21

## Context

Mail is read and answered from three accounts: two Google accounts and one
Proton Mail account behind Proton Mail Bridge. The requirements are a fast,
clean, native client with a unified view, not a complete groupware suite.
Thunderbird was rejected as heavy and visually dated, the Proton Mail desktop
application as a slow web wrapper. Their leftover profiles were removed.

Native candidates in September 2026: Hylki (Rust, libadwaita, unified inbox,
explicit Proton Bridge support, Flatpak only), Convey (GTK4 fork of Geary, in
AUR, no unified inbox, depends on evolution-data-server), Geary 46 (GTK3,
unmaintained since 2024). All three authenticate Google accounts through
GNOME Online Accounts.

The repository so far allowed only official and AUR packages.

## Decision

Adopt Hylki as the mail client and add Flatpak as a third, last-resort package
tier recorded in `packages/flatpak.txt`, used only when no official or AUR
package exists. Record `flatpak`, `gnome-online-accounts`, and
`gnome-control-center` in the official manifest; the latter is the only user
interface that can add GNOME Online Accounts.

Reach Proton Mail through the already managed Bridge service as a generic IMAP
and SMTP account. Bind `Mod3+M` to focus-or-spawn Hylki and `Mod3+Shift+M` to
compose through `mailto:`, register Hylki as the `mailto:` and `mid:` handler,
and open it on the `chat` workspace. Account data stays in Hylki's Flatpak
data directory and is not managed.

## Consequences

- One native client covers all three accounts with a unified inbox.
- The Hylki remote is operated by its developer, not Flathub; its GPG key is
  trusted on installation. Updates arrive through `flatpak update`.
- The sandbox has read access to the home directory and talks to GNOME Online
  Accounts, the secret service, and Nautilus over the session bus.
- Hylki is young and maintained by a small team with AI assistance. If it is
  abandoned, Convey is the drop-in alternative with the same account setup.
- After Flatpak is installed for the first time, already running processes
  lack the export path in `XDG_DATA_DIRS`; a shell restart or re-login fixes
  the launcher.
- `scripts/check-packages.sh` also reports missing Flatpak applications.

## Alternatives considered

- **Convey:** mature Geary engine and an AUR package, but no unified inbox and
  a heavier dependency chain. Kept as fallback.
- **Geary:** stable but GTK3 and without upstream maintenance.
- **Mailspring:** polished, but Electron.
- **aerc or neomutt:** fast terminal clients, but HTML mail rendering does not
  meet the visual requirement.
- **Building Hylki from source into an AUR package:** avoids the third-party
  remote but adds a Rust build to every update for no functional gain.
