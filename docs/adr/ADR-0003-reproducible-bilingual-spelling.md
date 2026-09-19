# ADR-0003: Reproducible bilingual spelling

- Status: Accepted
- Date: 2026-09-19

## Context

Daily writing mixes Dutch and English. System dictionaries alone do not
configure every application's spell checker, and Linux applications do not
all follow a shared spelling-language setting.

## Decision

Record Hunspell, Dutch and US English dictionaries, and Enchant in the official
package manifest. Use Dutch (`nl_NL`) and US English (`en_US`) as the documented
baseline, matching the dictionaries currently installed on this machine.
Prefer both languages enabled together where an application supports it.

Manage application preferences through `chezmoi/` only after their supported
configuration and behavior have been verified. Do not version complete browser
or Electron profiles, downloaded dictionaries, or personal dictionaries.
Document explicit installation and verification in `docs/spelling.md`.

## Consequences

- Dictionary prerequisites are reproducible after a fresh installation.
- Installation remains explicit; bootstrap does not install packages.
- No global language shortcut or universal app integration is promised.
- Application language preferences still require separate, verified integrations.
- The failed Electron Preferences workaround is not deployed automatically.

## Alternatives considered

- **Input-method suggestions:** change typing behavior without configuring the
  application's existing spell checker.
- **Global preference-rewriting script:** requires application-specific handling
  and may race with running applications or require restarts.
- **Combined custom dictionary:** adds maintenance and does not solve application
  integration; use native multi-dictionary support where available.
