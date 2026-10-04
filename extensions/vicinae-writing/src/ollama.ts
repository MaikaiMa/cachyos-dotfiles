export type OllamaSettings = {
	url: string;
	model: string;
};

const KEEP_ALIVE = "10m";

export class OllamaError extends Error {}

function endpoint(settings: OllamaSettings, path: string): string {
	return `${settings.url.replace(/\/+$/, "")}${path}`;
}

// Loading the model takes about ten seconds; starting it when the command
// opens overlaps that with choosing an action.
export function preloadModel(settings: OllamaSettings): void {
	fetch(endpoint(settings, "/api/generate"), {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify({ model: settings.model, keep_alive: KEEP_ALIVE }),
	}).catch(() => undefined);
}

async function failureMessage(
	settings: OllamaSettings,
	response: Response,
): Promise<string> {
	const body = await response.text().catch(() => "");
	let detail = body;
	try {
		detail = (JSON.parse(body) as { error?: string }).error ?? body;
	} catch {
		// Not JSON; keep the raw body.
	}
	if (response.status === 404 && /not found/i.test(detail)) {
		return `The model ${settings.model} is not installed. Pull it with: ollama pull ${settings.model}`;
	}
	return `Ollama answered ${response.status}: ${detail || response.statusText}`;
}

export async function streamChat(
	settings: OllamaSettings,
	system: string,
	text: string,
	onText: (soFar: string) => void,
	signal: AbortSignal,
): Promise<string> {
	let response: Response;
	try {
		response = await fetch(endpoint(settings, "/api/chat"), {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			signal,
			body: JSON.stringify({
				model: settings.model,
				stream: true,
				// Gemma 4 otherwise thinks first: 20 to 100 seconds and often an empty answer.
				think: false,
				keep_alive: KEEP_ALIVE,
				options: { temperature: 0.2, num_ctx: 4096 },
				messages: [
					{ role: "system", content: system },
					{ role: "user", content: text },
				],
			}),
		});
	} catch (error) {
		if (signal.aborted) throw error;
		throw new OllamaError(
			`Ollama is not reachable at ${settings.url}. Start it with: systemctl --user start ollama.service`,
		);
	}

	if (!response.ok || !response.body) {
		throw new OllamaError(await failureMessage(settings, response));
	}

	const decoder = new TextDecoder();
	const reader = response.body.getReader();
	let buffered = "";
	let output = "";

	const handleLine = (line: string) => {
		if (!line.trim()) return;
		const chunk = JSON.parse(line) as {
			message?: { content?: string };
			error?: string;
		};
		if (chunk.error) throw new OllamaError(chunk.error);
		const piece = chunk.message?.content ?? "";
		if (piece) {
			output += piece;
			onText(output);
		}
	};

	for (;;) {
		const { done, value } = await reader.read();
		if (done) break;
		buffered += decoder.decode(value, { stream: true });
		const lines = buffered.split("\n");
		buffered = lines.pop() ?? "";
		lines.forEach(handleLine);
	}
	handleLine(buffered + decoder.decode());

	return output.trim();
}
