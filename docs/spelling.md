# Dutch and English spelling

## Fresh installation

The spelling packages are recorded in `packages/pacman.txt`. Install them
explicitly after the normal system update:

```sh
sudo pacman -S --needed hunspell hunspell-nl hunspell-en_us enchant curl
```

This command is safe to repeat. Neither `scripts/bootstrap.sh` nor a chezmoi
apply installs these spelling packages. No additional spelling service is
required for this baseline.

## Verify the shared dictionaries

```sh
hunspell -D
enchant-lsmod-2 -list-dicts
printf '%s\n' 'fiets bicycle' | hunspell -d nl_NL,en_US -l
printf '%s\n' 'qzxqzxqzx' | hunspell -d nl_NL,en_US -l
```

The dictionary listings should contain `nl_NL` and `en_US`. The first text
check should produce no output: both words are accepted with the two
dictionaries active. The second should print `qzxqzxqzx`. These checks verify
the shared spelling engine, not any application's integration with it.

US English matches the currently installed dictionary. If British English is
preferred later, update the package manifest, language choices, and checks
together; do not assume `en_US` includes British spellings.

## Application integration

Current coverage:

| Component | Repository coverage |
| --- | --- |
| Hunspell dictionaries | Dutch and US English package prerequisites |
| Enchant applications | Dictionary access; language selection remains app-specific |
| ChatGPT Desktop | Managed helper for British English and Dutch; live behavior requires final verification |
| Other Electron apps | No verified language configuration deployed |
| Global spelling-language shortcut | Not implemented; apps do not share a universal setting |

### ChatGPT Desktop

The official Linux app stores its Chromium profile in `~/.config/Codex` and
does not expose a spelling-language selector in its context menu. After
applying chezmoi, close ChatGPT completely and run:

```sh
configure-chatgpt-spelling
```

The helper downloads Chromium's versioned Dutch `nl-NL-3-0.bdic` dictionary,
validates its `BDic` header, and atomically enables `en-GB` and `nl-NL` in the
profile. It refuses to modify the profile while ChatGPT is running. The
downloaded dictionary and the complete profile remain machine-local because
the profile can contain account and browsing state.

After restarting ChatGPT, type `fiets bicycle qzxqzxqzx` in the composer.
`fiets` and `bicycle` should be accepted; `qzxqzxqzx` should be underlined.
Repeat the check after one additional restart. Until that succeeds, treat this
integration as provisional rather than verified.

Where supported, enable Dutch and English simultaneously in the application's
spelling preferences. Installing a dictionary or selecting a keyboard layout
does not itself enable that language in every spell checker. Sandboxed apps
may also need dictionaries supplied within their own runtime.

For each future managed application:

1. Identify its documented preference for active spelling languages.
2. Verify both languages using `fiets bicycle` and a deliberate typo, including
   after restarting the application.
3. Add only the required preferences to `chezmoi/`, preserving unrelated settings.
4. Record the integration and any restart requirement in this guide.

Do not import complete application profiles: they can contain account details,
tokens, browsing state, and machine-specific data. Do not automatically rewrite
a running application's preferences. A plain `spellcheck.dictionaries` edit did
not solve the observed problem; the managed ChatGPT helper also installs the
required versioned Chromium dictionary and keeps Chromium's selected-language
preference in sync.

Background: [ArchWiki language checking](https://wiki.archlinux.org/title/Language_checking)
and [Electron spelling support](https://www.electronjs.org/docs/latest/tutorial/spellchecker).
See [ADR-0003](adr/ADR-0003-reproducible-bilingual-spelling.md) for the scope decision.
