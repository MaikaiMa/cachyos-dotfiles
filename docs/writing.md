# Writing Tools: fix, rewrite, and translate

Writing Tools is the repository's own Vicinae extension for working on text,
the replacement for Raycast's AI commands. It runs on a local model through
Ollama by default and asks Claude only when that is chosen. Why it is built
this way, the measurements, and the alternatives are in
[ADR-0026](adr/ADR-0026-local-first-writing-tools-with-ollama-and-claude-on-request.md).

## Using it

Select text in any app and press `Mod+I`, or search for "Writing Tools" in the
launcher (`Mod+Space`). The list groups short action names under section
headers. The side panel describes the highlighted action in one line and
shows the text it will work on below that. Typing in the search bar filters
across all sections and also matches the longer names, such as "fix",
"improve", "make shorter", or "concise".

| Section | Action | Does |
| --- | --- | --- |
| Fix | Spelling & Grammar | Corrects only spelling, grammar, and punctuation; the wording stays. |
| Improve | Clarity & Flow | Clearer and more natural, same meaning and tone. |
| Improve | Professional | Businesslike but not stiff. |
| Improve | Casual | A relaxed tone. |
| Improve | Friendly | A warm tone. |
| Length | Shorter | As short as possible without losing information. |
| Length | Longer | Elaborates only on what is already there (explains, connects, smooths); never adds facts, names, numbers, dates, promises, or commitments. |
| Translate | To English, To Dutch | The direction opposite the detected language comes first, the other stays as an override; the side panel names the detected language. When the language is unclear, "Dutch ↔ English" lets the model decide. |
| — | Instruction: *what you typed* | Appears when the search text matches no action, and uses that text as the instruction. |

A longer instruction can also be written in a form: "Custom Instruction…"
in the action panel of any item, or `Ctrl+I`.

Every action keeps the language of the text, except the translations.

Dutch form of address: Fix, Improve, and Length keep the source's *je* or
*u*, also Professional; translations and newly written Dutch use *je*.
The result never mixes the two, and no greeting or sign-off is added unless
the instruction asks for one. Formatting, line breaks, and lists are kept.

Keys in the list and in the result:

| Key | In the list | In the result |
| --- | --- | --- |
| `Enter` | Run the action locally | Paste over the selection (or at the cursor) |
| `Ctrl+Enter` | Run the action with Claude | — |
| `Ctrl+E` | Edit the text first | — |
| `Ctrl+I` | Write a custom instruction | — |
| `Ctrl+Shift+C` | — | Copy the result |
| `Ctrl+L` | — | Retry with Claude |
| `Ctrl+R` | — | Retry locally |
| `Ctrl+B` | All actions | All actions |

The result streams into the preview; the side panel shows which model
answered and how long it took. Paste and Copy appear once the answer is
complete.

Without selected text, a form asks for the text first. Text typed in the root
search before choosing Writing Tools is used the same way.

## How it works

- **Selection:** Vicinae reads the primary selection, the text that was last
  selected anywhere. That is usually the current selection, but it can be an
  older one that is no longer highlighted; the side panel shows which text
  is used, and `Ctrl+E` changes it.
- **Paste:** Enter closes Vicinae, waits until the previous window has focus
  again, and sends the paste shortcut (`Ctrl+Shift+V` in terminals) through
  Vicinae's input helper; the clipboard is restored afterwards. The app still
  has the text selected, so the paste replaces it. When the selection is
  gone, the result is inserted at the cursor instead.
- **Local model:** opening the command sends Ollama a load request, so the
  roughly ten-second cold start overlaps with choosing an action. Requests
  stream from `http://127.0.0.1:11434` with thinking off (Gemma 4 otherwise
  thinks for 20 to 100 seconds and often answers with nothing), a 4096-token
  context, and temperature 0.2. The model stays loaded for 10 minutes after
  the last request.
- **Claude:** "Run with Claude" and "Retry with Claude" run the official
  `claude -p --model sonnet` without tools, settings, or a saved session, with
  the text on standard input. They only appear when `claude` is on `PATH` and
  use the Claude login of the user. A request takes about four seconds.
  Whether a client text may go to Claude follows the ISMS.

## Files and services

| | Where |
| --- | --- |
| Extension source | `extensions/vicinae-writing/` (TypeScript, `@vicinae/api`) |
| Installed extension | `~/.local/share/vicinae/extensions/writing-tools`, built by `scripts/build-vicinae-extensions.sh` |
| Vicinae command id | `@maikel/writing-tools/writing-tools`: `@<author>/<install directory>/<command>` |
| Ollama | `~/.config/systemd/user/ollama.service`, enabled through `niri.service.wants/ollama.service` |
| Models | `~/.ollama` (not managed) |
| Shortcut | `Mod+I` in `chezmoi/dot_config/niri/cfg/keybinds.kdl` |

The user unit runs `ollama serve` on 127.0.0.1 with the Vulkan backend, one
loaded model, a 4096-token context, a 10-minute keep-alive, and at most 20 GB
of memory. It starts and stops with the Niri session, so it does not run in
the Steam session.

The `ollama` package also ships a system `ollama.service`. Keep it disabled:
it would bind the same port and keep its own models in `/var/lib/ollama`.

## First-time setup

Install the packages recorded in `packages/pacman.txt` (`ollama`,
`ollama-vulkan`, `nodejs`, `npm`), check that the system service is not
enabled, and apply the dotfiles as described in the
[maintenance guide](maintenance.md). Bootstrap builds and installs the
extension when Vicinae is installed.

```fish
systemctl is-enabled ollama.service
```

It must print `disabled`. Then start the user service and download the model
once (about 16 GB):

```fish
systemctl --user daemon-reload
systemctl --user start ollama.service
ollama pull gemma4:26b-a4b-it-qat
```

Build the extension by hand when bootstrap did not, or after changing it:

```fish
./scripts/build-vicinae-extensions.sh
```

Vicinae picks the new extension up by itself. Select some text, press
`Mod+I`, and run Fix Spelling & Grammar.

## Preferences and switching models

The preferences are in Vicinae's settings (`Ctrl+,`) under Extensions,
Writing Tools:

- **Ollama model:** default `gemma4:26b-a4b-it-qat`. Pull another model
  first, for example the smaller and slower `gemma4:12b-it-q4_K_M` (about
  8 GB), then enter its name.
- **Ollama address:** default `http://127.0.0.1:11434`.
- **Claude model:** default `sonnet`; any alias `claude --model` accepts.

The default model is defined once, in `extensions/vicinae-writing/package.json`;
bootstrap reads it from there to report when it is not installed. Remove a
model that is no longer used with `ollama rm`.

## Changing the extension

Edit the files under `extensions/vicinae-writing/src`; the prompts are in
`src/prompts.ts`. For live reloading while editing:

```fish
cd extensions/vicinae-writing
npm ci
npm run dev
```

`tests/validate.sh` type-checks the extension and lints its manifest once
`node_modules` exists there; without it, validation prints a skip line and
stays offline. Install the result with `./scripts/build-vicinae-extensions.sh`,
which rebuilds only when a source file changed (`--force` rebuilds anyway).
Keep the `@vicinae/api` version in `package.json` in step with the installed
`vicinae-bin`.

## Troubleshooting

Check whether the model is loaded and where it runs:

```fish
ollama ps
```

`PROCESSOR` should say `100% GPU`. When it shows CPU, the integrated GPU
was not used: `OLLAMA_IGPU_ENABLE=1` in the unit is what makes Ollama use the
Radeon 8060S. Check that the running service has it and look for Vulkan in
the log:

```fish
systemctl --user show ollama.service -p Environment
journalctl --user -b -u ollama.service | grep -i vulkan
```

Other problems:

- **"Ollama is not reachable":** the service is not running; start it with
  `systemctl --user start ollama.service`. Another Ollama on the same port
  (the system service, or a test started with `systemd-run`) keeps the user
  service from starting; stop that one first.
- **"The model … is not installed":** pull it with `ollama pull` and the name
  shown.
- **Slow first answer:** the model is loading (about ten seconds). It stays
  loaded for 10 minutes after the last request.
- **Memory:** the model takes about 16 GB of shared memory while loaded. The
  unit allows one model and 20 GB at most, so Ollama is stopped before the
  session runs out; unload the model right away with
  `ollama stop gemma4:26b-a4b-it-qat`.
- **Long texts:** above about 6000 characters the local context may cut the
  text off; the extension warns, and Retry with Claude handles it.
- **No Claude actions:** `claude` is not on the `PATH` of the Vicinae service.
- **The paste lands in the wrong place or adds text instead of replacing:**
  the selection was gone by the time of the paste; select the text again and
  use Copy if needed.
- **The extension is missing from Vicinae:** run
  `./scripts/build-vicinae-extensions.sh --force` and check the output.
