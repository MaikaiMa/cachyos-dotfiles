import {
	Action,
	ActionPanel,
	Detail,
	Form,
	getPreferenceValues,
	getSelectedText,
	Icon,
	type LaunchProps,
	List,
	showToast,
	Toast,
	useNavigation,
} from "@vicinae/api";
import { useEffect, useMemo, useState } from "react";
import { findClaude, runClaude } from "./claude";
import { type OllamaSettings, preloadModel, streamChat } from "./ollama";
import {
	detectLanguage,
	type Language,
	type Length,
	otherLanguage,
	systemPrompt,
	type Task,
	type Tone,
} from "./prompts";

type Settings = {
	ollama: OllamaSettings;
	claudeModel: string;
	claudePath?: string;
};

type Source = {
	text: string;
	fromSelection: boolean;
};

type Backend = "local" | "claude";

type SectionName = "Fix" | "Improve" | "Length" | "Translate";

type Choice = {
	id: string;
	section: SectionName;
	title: string;
	description: string;
	icon: Icon;
	keywords: string[];
	task: Task;
};

const SECTIONS: SectionName[] = ["Fix", "Improve", "Length", "Translate"];

const KEEPS_ADDRESS = "Keeps your je/u.";

const TONE_TITLES: Record<Tone, string> = {
	professional: "Make Professional",
	casual: "Make Casual",
	friendly: "Make Friendly",
};

const LENGTH_TITLES: Record<Length, string> = {
	shorter: "Make Shorter",
	longer: "Make Longer",
};

// Roughly what fits next to the answer in the 4096-token context of the local model.
const LOCAL_CONTEXT_CHARACTERS = 6000;

function readSettings(): Settings {
	const preferences = getPreferenceValues<{
		ollamaModel?: string;
		ollamaUrl?: string;
		claudeModel?: string;
	}>();
	return {
		ollama: {
			model: preferences.ollamaModel?.trim() || "gemma4:26b-a4b-it-qat",
			url: preferences.ollamaUrl?.trim() || "http://127.0.0.1:11434",
		},
		claudeModel: preferences.claudeModel?.trim() || "sonnet",
		claudePath: findClaude(),
	};
}

function translateChoice(target: Language, description: string): Choice {
	return {
		id: `translate-${target}`,
		section: "Translate",
		title: `To ${target}`,
		description,
		icon: Icon.SpeechBubble,
		keywords: [
			"translate",
			`translate to ${target.toLowerCase()}`,
			"vertaal",
			target.toLowerCase(),
		],
		task: { kind: "translate", target },
	};
}

const DUTCH_ADDRESS = "Dutch addresses the reader with je.";

function translateChoices(text: string): Choice[] {
	const detected = detectLanguage(text);
	if (detected) {
		const other = otherLanguage(detected);
		return [
			translateChoice(
				other,
				`detected ${detected}, translates into ${other}.${other === "Dutch" ? ` ${DUTCH_ADDRESS}` : ""}`,
			),
			translateChoice(
				detected,
				`for when the detection (${detected}) is wrong; translates into ${detected}.${detected === "Dutch" ? ` ${DUTCH_ADDRESS}` : ""}`,
			),
		];
	}
	return [
		{
			id: "translate-auto",
			section: "Translate",
			title: "Dutch ↔ English",
			description:
				"language unclear; the model translates Dutch into English and anything else into Dutch.",
			icon: Icon.SpeechBubbleActive,
			keywords: ["translate", "vertaal", "dutch", "english", "auto"],
			task: { kind: "translate", target: "auto" },
		},
		translateChoice("English", "translates into English."),
		translateChoice("Dutch", `translates into Dutch. ${DUTCH_ADDRESS}`),
	];
}

function choices(text: string): Choice[] {
	const tone = (
		id: Tone,
		title: string,
		description: string,
		icon: Icon,
	): Choice => ({
		id: `tone-${id}`,
		section: "Improve",
		title,
		description: `${description} ${KEEPS_ADDRESS}`,
		icon,
		keywords: [TONE_TITLES[id].toLowerCase(), "tone", "rewrite", "toon", "improve"],
		task: { kind: "tone", tone: id },
	});
	const length = (
		id: Length,
		title: string,
		description: string,
		icon: Icon,
		keywords: string[],
	): Choice => ({
		id: `length-${id}`,
		section: "Length",
		title,
		description: `${description} ${KEEPS_ADDRESS}`,
		icon,
		keywords: [LENGTH_TITLES[id].toLowerCase(), "length", "lengte", ...keywords],
		task: { kind: "length", length: id },
	});
	return [
		{
			id: "fix",
			section: "Fix",
			title: "Spelling & Grammar",
			description: `corrects only spelling, grammar and punctuation; the wording stays. ${KEEPS_ADDRESS}`,
			icon: Icon.CheckCircle,
			keywords: ["fix spelling & grammar", "fix", "typo", "punctuation", "spelfout"],
			task: { kind: "fix" },
		},
		{
			id: "improve",
			section: "Improve",
			title: "Clarity & Flow",
			description: `clearer and more natural, same meaning and tone. ${KEEPS_ADDRESS}`,
			icon: Icon.Wand,
			keywords: ["improve clarity & flow", "improve writing", "improve", "verbeter", "clearer"],
			task: { kind: "improve" },
		},
		tone("professional", "Professional", "businesslike, not stiff.", Icon.Person),
		tone("casual", "Casual", "relaxed tone, same meaning.", Icon.SpeechBubble),
		tone("friendly", "Friendly", "warm tone, same meaning.", Icon.Heart),
		length("shorter", "Shorter", "as short as possible without losing information.", Icon.Minimize, [
			"concise",
			"korter",
			"shorten",
		]),
		length(
			"longer",
			"Longer",
			"elaborates only on what is already there; adds no new facts, names, numbers, dates or commitments.",
			Icon.Paragraph,
			["langer", "elaborate", "expand"],
		),
		...translateChoices(text),
	];
}

function taskTitle(task: Task): string {
	switch (task.kind) {
		case "fix":
			return "Fix Spelling & Grammar";
		case "improve":
			return "Improve Clarity & Flow";
		case "tone":
			return TONE_TITLES[task.tone];
		case "length":
			return LENGTH_TITLES[task.length];
		case "custom":
			return task.instruction;
		case "translate":
			return task.target === "auto"
				? "Translate"
				: `Translate to ${task.target}`;
	}
}

// Markdown joins single line breaks; the preview keeps them.
function asMarkdown(text: string): string {
	return text.replace(/([^\n])\n(?!\n)/g, "$1  \n");
}

// The models trim their answer; a selection that ended in a line break keeps it.
function keepSurroundingWhitespace(source: string, output: string): string {
	const leading = source.match(/^\s*/)?.[0] ?? "";
	const trailing = source.match(/\s*$/)?.[0] ?? "";
	return `${leading}${output.trim()}${trailing}`;
}

function errorMessage(error: unknown): string {
	return error instanceof Error ? error.message : String(error);
}

export default function Command(props: LaunchProps) {
	const settings = useMemo(readSettings, []);
	const [source, setSource] = useState<Source>();
	const [isReading, setIsReading] = useState(true);

	useEffect(() => {
		preloadModel(settings.ollama);
		getSelectedText()
			.catch(() => "")
			.then((selected) => {
				const typed = props.fallbackText ?? "";
				if (selected.trim()) {
					setSource({ text: selected, fromSelection: true });
				} else if (typed.trim()) {
					setSource({ text: typed, fromSelection: false });
				}
				setIsReading(false);
			});
	}, []);

	if (isReading) return <List isLoading />;
	if (!source) {
		return (
			<TextForm
				onSubmit={(text) => setSource({ text, fromSelection: false })}
			/>
		);
	}
	return <TaskList source={source} settings={settings} onEdit={setSource} />;
}

function TextForm(props: {
	initialText?: string;
	onSubmit: (text: string) => void;
}) {
	return (
		<Form
			navigationTitle="Writing Tools"
			actions={
				<ActionPanel>
					<Action.SubmitForm
						title="Continue"
						icon={Icon.ArrowRight}
						onSubmit={(values: { text?: string }) => {
							const text = values.text ?? "";
							if (!text.trim()) {
								showToast({
									style: Toast.Style.Failure,
									title: "Type or paste some text first",
								});
								return;
							}
							props.onSubmit(text);
						}}
					/>
				</ActionPanel>
			}
		>
			<Form.TextArea
				id="text"
				title="Text"
				placeholder="No text was selected. Type or paste the text to work on."
				defaultValue={props.initialText}
				autoFocus
			/>
		</Form>
	);
}

function InstructionForm(props: {
	source: Source;
	settings: Settings;
}) {
	const { push } = useNavigation();
	const start = (values: { instruction?: string }, backend: Backend) => {
		const instruction = values.instruction?.trim() ?? "";
		if (!instruction) {
			showToast({ style: Toast.Style.Failure, title: "Type an instruction" });
			return;
		}
		push(
			<Result
				task={{ kind: "custom", instruction }}
				source={props.source}
				settings={props.settings}
				backend={backend}
			/>,
		);
	};
	return (
		<Form
			navigationTitle="Custom Instruction"
			actions={
				<ActionPanel>
					<Action.SubmitForm
						title="Run Locally"
						icon={Icon.ComputerChip}
						onSubmit={(values: { instruction?: string }) =>
							start(values, "local")
						}
					/>
					{props.settings.claudePath && (
						<Action.SubmitForm
							title="Run with Claude"
							icon={Icon.Stars}
							shortcut={{ modifiers: ["ctrl"], key: "return" }}
							onSubmit={(values: { instruction?: string }) =>
								start(values, "claude")
							}
						/>
					)}
				</ActionPanel>
			}
		>
			<Form.TextField
				id="instruction"
				title="Instruction"
				placeholder="For example: turn this into three bullet points"
				autoFocus
			/>
		</Form>
	);
}

function TaskList(props: {
	source: Source;
	settings: Settings;
	onEdit: (source: Source) => void;
}) {
	const { source, settings } = props;
	const [search, setSearch] = useState("");
	const all = useMemo(() => choices(source.text), [source.text]);
	const query = search.trim().toLowerCase();
	const visible = all.filter(
		(choice) =>
			!query ||
			[choice.title, choice.section, ...choice.keywords].some((text) =>
				text.toLowerCase().includes(query),
			),
	);
	const typedInstruction = visible.length === 0 ? search.trim() : "";
	const sourceBlock = `**${source.fromSelection ? "Selected text" : "Text"}**\n\n${asMarkdown(source.text)}`;
	const detail = (summary: string) => (
		<List.Item.Detail markdown={`${summary}\n\n---\n\n${sourceBlock}`} />
	);

	const actionsFor = (task: Task) => (
		<ActionPanel>
			<Action.Push
				title="Run Locally"
				icon={Icon.ComputerChip}
				target={
					<Result
						task={task}
						source={source}
						settings={settings}
						backend="local"
					/>
				}
			/>
			{settings.claudePath && (
				<Action.Push
					title="Run with Claude"
					icon={Icon.Stars}
					shortcut={{ modifiers: ["ctrl"], key: "return" }}
					target={
						<Result
							task={task}
							source={source}
							settings={settings}
							backend="claude"
						/>
					}
				/>
			)}
			<EditTextAction source={source} onEdit={props.onEdit} />
			<Action.Push
				title="Custom Instruction…"
				icon={Icon.Pencil}
				shortcut={{ modifiers: ["ctrl"], key: "i" }}
				target={<InstructionForm source={source} settings={settings} />}
			/>
		</ActionPanel>
	);

	return (
		<List
			isShowingDetail
			filtering={false}
			searchText={search}
			onSearchTextChange={setSearch}
			navigationTitle="Writing Tools"
			searchBarPlaceholder="Choose an action, or type an instruction"
		>
			{SECTIONS.map((section) => (
				<List.Section key={section} title={section}>
					{visible
						.filter((choice) => choice.section === section)
						.map((choice) => (
							<List.Item
								key={choice.id}
								title={choice.title}
								icon={choice.icon}
								detail={detail(
									`**${choice.section} › ${choice.title}**: ${choice.description}`,
								)}
								actions={actionsFor(choice.task)}
							/>
						))}
				</List.Section>
			))}
			{typedInstruction && (
				<List.Item
					key="typed-instruction"
					title={`Instruction: ${typedInstruction}`}
					icon={Icon.Pencil}
					detail={detail(
						"**Instruction**: applies what you typed to the text. Keeps your je/u unless the instruction says otherwise.",
					)}
					actions={actionsFor({ kind: "custom", instruction: typedInstruction })}
				/>
			)}
		</List>
	);
}

function EditTextAction(props: {
	source: Source;
	onEdit: (source: Source) => void;
}) {
	const { pop } = useNavigation();
	return (
		<Action.Push
			title="Edit Text"
			icon={Icon.TextCursor}
			shortcut={{ modifiers: ["ctrl"], key: "e" }}
			target={
				<TextForm
					initialText={props.source.text}
					onSubmit={(text) => {
						props.onEdit({
							text,
							fromSelection:
								props.source.fromSelection && text === props.source.text,
						});
						pop();
					}}
				/>
			}
		/>
	);
}

type Outcome =
	| { status: "running"; output: string }
	| { status: "done"; output: string; seconds: number }
	| { status: "failed"; error: string };

function Result(props: {
	task: Task;
	source: Source;
	settings: Settings;
	backend: Backend;
}) {
	const { task, source, settings } = props;
	const [backend, setBackend] = useState<Backend>(props.backend);
	const [attempt, setAttempt] = useState(0);
	const [outcome, setOutcome] = useState<Outcome>({
		status: "running",
		output: "",
	});

	useEffect(() => {
		const controller = new AbortController();
		const started = Date.now();
		const system = systemPrompt(task);
		setOutcome({ status: "running", output: "" });

		if (backend === "local" && source.text.length > LOCAL_CONTEXT_CHARACTERS) {
			showToast({
				style: Toast.Style.Failure,
				title: "Long text",
				message:
					"The local model may cut it off; Retry with Claude if the result is incomplete.",
			});
		}

		const request =
			backend === "claude" && settings.claudePath
				? runClaude(
						settings.claudePath,
						settings.claudeModel,
						system,
						source.text,
						controller.signal,
					)
				: streamChat(
						settings.ollama,
						system,
						source.text,
						(soFar) => setOutcome({ status: "running", output: soFar }),
						controller.signal,
					);

		request
			.then((output) => {
				if (!output.trim()) throw new Error("The model returned no text.");
				setOutcome({
					status: "done",
					output: keepSurroundingWhitespace(source.text, output),
					seconds: (Date.now() - started) / 1000,
				});
			})
			.catch((error: unknown) => {
				if (controller.signal.aborted) return;
				setOutcome({ status: "failed", error: errorMessage(error) });
			});

		return () => controller.abort();
	}, [backend, attempt]);

	const retry = (next: Backend) => {
		setBackend(next);
		setAttempt((count) => count + 1);
	};

	const engine =
		backend === "claude"
			? `Claude (${settings.claudeModel})`
			: settings.ollama.model;

	let markdown: string;
	if (outcome.status === "failed") {
		markdown = `### Failed\n\n${asMarkdown(outcome.error)}`;
	} else if (outcome.output) {
		markdown = asMarkdown(outcome.output);
	} else {
		markdown =
			backend === "claude"
				? "_Asking Claude…_"
				: "_Waiting for the local model; the first request after a while loads it, which takes about ten seconds…_";
	}

	const retryActions = (
		<>
			{settings.claudePath && (
				<Action
					title="Retry with Claude"
					icon={Icon.Stars}
					shortcut={{ modifiers: ["ctrl"], key: "l" }}
					onAction={() => retry("claude")}
				/>
			)}
			<Action
				title="Retry Locally"
				icon={Icon.ArrowClockwise}
				shortcut={{ modifiers: ["ctrl"], key: "r" }}
				onAction={() => retry("local")}
			/>
		</>
	);

	return (
		<Detail
			navigationTitle={
				outcome.status === "running"
					? `${taskTitle(task)} — writing…`
					: taskTitle(task)
			}
			markdown={markdown}
			metadata={
				<Detail.Metadata>
					<Detail.Metadata.Label title="Action" text={taskTitle(task)} />
					<Detail.Metadata.Label title="Model" text={engine} />
					{outcome.status === "done" && (
						<Detail.Metadata.Label
							title="Time"
							text={`${outcome.seconds.toFixed(1)} s`}
						/>
					)}
				</Detail.Metadata>
			}
			actions={
				outcome.status === "done" ? (
					<ActionPanel>
						<Action.Paste
							title={source.fromSelection ? "Paste over Selection" : "Paste"}
							content={outcome.output}
						/>
						<Action.CopyToClipboard
							content={outcome.output}
							shortcut={{ modifiers: ["ctrl", "shift"], key: "c" }}
						/>
						{retryActions}
					</ActionPanel>
				) : (
					<ActionPanel>{retryActions}</ActionPanel>
				)
			}
		/>
	);
}
