import { spawn } from "node:child_process";
import { accessSync, constants } from "node:fs";
import { delimiter, join } from "node:path";

export function findClaude(): string | undefined {
	for (const directory of (process.env.PATH ?? "").split(delimiter)) {
		if (!directory) continue;
		const candidate = join(directory, "claude");
		try {
			accessSync(candidate, constants.X_OK);
			return candidate;
		} catch {
			// Not in this directory.
		}
	}
	return undefined;
}

// Only the official claude binary is used, so the request runs under the
// user's own subscription. The text goes over stdin: as an argument, text
// that starts with "-" is parsed as an option.
export function runClaude(
	executable: string,
	model: string,
	system: string,
	text: string,
	signal: AbortSignal,
): Promise<string> {
	return new Promise((resolve, reject) => {
		const child = spawn(
			executable,
			[
				"-p",
				"--model",
				model,
				"--tools",
				"",
				"--setting-sources",
				"",
				"--no-session-persistence",
				"--system-prompt",
				system,
			],
			{ signal, stdio: ["pipe", "pipe", "pipe"] },
		);

		let stdout = "";
		let stderr = "";
		child.stdout.setEncoding("utf8").on("data", (data: string) => {
			stdout += data;
		});
		child.stderr.setEncoding("utf8").on("data", (data: string) => {
			stderr += data;
		});
		child.on("error", reject);
		child.on("close", (code) => {
			if (code === 0 && stdout.trim()) {
				resolve(stdout.trim());
			} else {
				reject(
					new Error(
						(stderr || stdout).trim() || `claude exited with status ${code}`,
					),
				);
			}
		});
		child.stdin.on("error", () => undefined);
		child.stdin.end(text);
	});
}
