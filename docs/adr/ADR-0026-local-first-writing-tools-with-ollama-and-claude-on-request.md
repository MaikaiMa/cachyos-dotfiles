# ADR-0026: Local-first writing tools with Ollama, Claude on request

- Status: Accepted
- Date: 2026-10-04
- Builds on: [ADR-0024](ADR-0024-replace-dms-spotlight-with-vicinae-and-add-handy-dictation.md)
  (Vicinae is the launcher that hosts the extension)

## Context

On macOS, Raycast's AI commands were used daily to fix spelling, improve a
text, change its tone, and translate between Dutch and English, directly on
the selected text. Vicinae has no built-in equivalent, and its Raycast-store
AI extensions need a paid provider.

The requirements, in order:

1. No extra usage-based cost. Subscriptions come and go, so the tool must
   work on its own without one.
2. Texts often belong to clients that fall under ISO 27001. They must not be
   used for training, and the provider must be covered by an agreement the
   employer has; see the ISMS for what may be shared where.
3. Dutch and English at a quality that needs no manual correction, with a
   consistent form of address (je or u, never mixed).
4. Fast enough to use inline: open, choose, paste.

Options that were checked:

- **Gemini API free tier:** no training on EEA traffic, but a personal key
  is not covered by any agreement of the employer.
- **DeepL Free:** trains on submitted texts; ruled out for client texts.
- **Claude API:** good, but billed per token on top of the existing Team
  subscription.
- **Claude through the official `claude` binary:** uses the Webbio Claude
  Team subscription that is already paid for, within Anthropic's terms
  (unmodified binary, used by the subscriber himself). Not permanent, so it
  cannot be the only path.
- **A local model with Ollama** on the Radeon 8060S (Vulkan, shared memory),
  measured on this machine with the same prompts and texts:

| Backend | Cold start | Warm request | Speed | Memory while loaded |
| --- | --- | --- | --- | --- |
| `gemma4:26b-a4b-it-qat` | 10.5 s (load 9.3 s) | 0.9 s | 68 tokens/s | about 16 GB |
| `gemma4:12b-it-q4_K_M` | 10.1 s (load 8.5 s) | 1.8 s | 56 tokens/s | about 8 GB |
| Claude Sonnet (`claude -p`) | — | 4.1 s | — | — |

The 26B mixture-of-experts model activates about 4B parameters per token, so
it answers twice as fast as the dense 12B model on this hardware, and its
Dutch and English output was good on the test texts. Gemma 4 must be called with
`"think": false`: with thinking on, requests took 20 to 100 seconds and often
returned an empty answer.

## Decision

Build a Vicinae extension, Writing Tools (`extensions/vicinae-writing`), in
this repository, opened with `Mod+I`:

- It reads the selected text (Vicinae's primary-selection API); without a
  selection the text is typed or pasted into a form.
- Actions, in sections: Fix (spelling and grammar); Improve (clarity and
  flow, professional, casual, friendly); Length (shorter, and longer without
  new facts, names, numbers, dates, or commitments); Translate (detects Dutch
  or English and offers the other first, with the reverse as an override).
  A custom instruction is typed in the search bar or written in a form from
  the action panel. Only Dutch and English.
- Fix, Improve, and Length keep the source's je or u; translations and newly
  written Dutch use je. No greetings or sign-offs are added.
- **Local by default:** Ollama with `gemma4:26b-a4b-it-qat` (a preference),
  streamed into the preview, `num_ctx` 4096, temperature 0.2, `keep_alive`
  10 minutes. Opening the command preloads the model, so the cold start
  overlaps with choosing an action.
- **Claude on request:** "Run with Claude" and "Retry with Claude" spawn the
  official `claude -p --model sonnet` without tools, settings, or session
  persistence, with the text on stdin. The actions only appear when `claude`
  is on `PATH`.
- Enter pastes the result over the selection; Copy and both retries are
  secondary actions.
- Ollama runs as a repository-owned systemd user unit started with the Niri
  session (the ADR-0007 pattern), bound to 127.0.0.1, one model at a time,
  capped at 20 GB of memory.
- The extension is built with Node and installed into Vicinae's extension
  directory by `scripts/build-vicinae-extensions.sh`, which bootstrap runs.
  The model is not pulled by bootstrap; it only reports when it is missing.

## Consequences

- Translating and rewriting work offline and cost nothing per request;
  client texts stay on the machine unless Claude is chosen explicitly.
- About 16 GB of the shared memory is in use while the model is loaded, for
  10 minutes after the last request. The service's `MemoryMax=20G` and
  `OLLAMA_MAX_LOADED_MODELS=1` keep a second model from pushing the session
  into systemd-oomd, which once killed a whole Ghostty scope.
- The first request after a pause waits about ten seconds for the model to
  load; preloading hides most of it.
- The packaged system `ollama.service` must stay disabled: it would bind the
  same port and keep its models in `/var/lib/ollama`. User models live in
  `~/.ollama`, which is not managed.
- `OLLAMA_IGPU_ENABLE=1` is required; without it Ollama ignores the
  integrated GPU and silently runs on the CPU.
- The repository gains a Node build step (`nodejs`, `npm`, a committed
  `package-lock.json`). Validation stays offline: the TypeScript check only
  runs where `node_modules` exists.
- Claude goes only through the official binary and the user's own login;
  the extension never reads its credentials. The Team plan's "extra usage"
  setting has to be confirmed off, so a Claude request can never be billed on
  top of the subscription. Whether a given client text may go to Claude at
  all follows the ISMS, not this ADR.
- The primary selection can be stale: when the text is no longer selected,
  the preview still shows it and Enter inserts at the cursor instead of
  replacing. The preview and "Edit Text" make that visible.
- A local text longer than about 6000 characters may not fit the 4096-token
  context; the extension warns and Claude is the fallback.

## Alternatives considered

- **Raycast-store AI extensions in Vicinae:** need a paid provider key.
- **Gemini or DeepL free tiers:** not contracted, and DeepL Free trains on
  the texts.
- **Claude API key:** per-token cost on top of the subscription.
- **`gemma4:12b`:** half the memory, but twice as slow per request as the
  26B mixture-of-experts model on this hardware. It remains a one-preference
  switch if memory becomes the constraint.
- **A shell script with `wl-paste` and `wtype` instead of an extension:** no
  preview, no retry, and no choice of action without another picker.
