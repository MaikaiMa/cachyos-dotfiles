export type Language = "Dutch" | "English";

export type Tone = "professional" | "casual" | "friendly";

export type Length = "shorter" | "longer";

export type Task =
	| { kind: "fix" }
	| { kind: "improve" }
	| { kind: "tone"; tone: Tone }
	| { kind: "length"; length: Length }
	| { kind: "custom"; instruction: string }
	| { kind: "translate"; target: Language | "auto" };

const OUTPUT_RULES =
	"Return only the resulting text: no preamble, no quotes, no explanation, no notes. " +
	"Do not add a greeting or sign-off unless the instruction asks for one. " +
	"Keep the original formatting, line breaks, lists and Markdown.";

const SAME_LANGUAGE =
	"Write in the language of the text: English stays English and Dutch stays Dutch; never translate.";

const KEEP_ADDRESS =
	"If the text is Dutch, keep its form of address exactly as it is: " +
	'informal "je/jij/jouw" stays informal and formal "u/uw" stays formal. ' +
	"Never mix je and u in one text.";

const DUTCH_DEFAULT_ADDRESS =
	'When the result is Dutch, address the reader informally with "je/jij/jouw", ' +
	'never with "u/uw", and use that form consistently throughout.';

const TONE_DESCRIPTIONS: Record<Tone, string> = {
	professional: "professional and businesslike, but not stiff",
	casual: "casual and relaxed",
	friendly: "warm and friendly",
};

const LENGTH_INSTRUCTIONS: Record<Length, string> = {
	shorter:
		"Make the text as short as possible without losing information, in the same language and with the same meaning and tone.",
	longer:
		"Make the text longer by elaborating only on what is already in it: explain, connect and smooth the existing points. " +
		"Never add new facts, names, numbers, dates, promises or commitments. " +
		"Keep the same language, meaning and tone.",
};

export function systemPrompt(task: Task): string {
	switch (task.kind) {
		case "fix":
			return [
				"Correct spelling, grammar and punctuation.",
				"Keep the wording, tone and language exactly as they are; change nothing that is not a mistake.",
				SAME_LANGUAGE,
				KEEP_ADDRESS,
				OUTPUT_RULES,
			].join(" ");
		case "improve":
			return [
				"Improve the writing: clearer, more natural and more concise, with the same meaning, tone and language.",
				SAME_LANGUAGE,
				KEEP_ADDRESS,
				OUTPUT_RULES,
			].join(" ");
		case "tone":
			return [
				`Rewrite the text in a ${TONE_DESCRIPTIONS[task.tone]} tone, in the same language and with the same meaning.`,
				SAME_LANGUAGE,
				KEEP_ADDRESS,
				OUTPUT_RULES,
			].join(" ");
		case "length":
			return [
				LENGTH_INSTRUCTIONS[task.length],
				SAME_LANGUAGE,
				KEEP_ADDRESS,
				OUTPUT_RULES,
			].join(" ");
		case "custom":
			return [
				`Apply this instruction to the text: ${task.instruction}`,
				"Answer in the language of the text unless the instruction asks for another language.",
				"If the text is Dutch and has a form of address, keep it unless the instruction asks otherwise.",
				`For newly written Dutch: ${DUTCH_DEFAULT_ADDRESS}`,
				"Never mix je and u in one text.",
				OUTPUT_RULES,
			].join(" ");
		case "translate":
			return [
				task.target === "auto"
					? "If the text is Dutch, translate it into English; otherwise translate it into Dutch."
					: `Translate the text into ${task.target}.`,
				"Keep the tone and register, and keep names, product names and code unchanged.",
				DUTCH_DEFAULT_ADDRESS,
				OUTPUT_RULES,
			].join(" ");
	}
}

const DUTCH_MARKERS = new Set(
	"de het een en van ik je jij u niet dat die is zijn er op met voor maar ook wat wel nog als bij naar om dan we wij hebben heeft kan kunnen moet graag geen deze dit".split(
		" ",
	),
);

const ENGLISH_MARKERS = new Set(
	"the a an and of to you is are that this it for with not but also what as at on we have has can could should would will be please no these from".split(
		" ",
	),
);

export function detectLanguage(text: string): Language | undefined {
	let dutch = 0;
	let english = 0;
	for (const word of text.toLowerCase().match(/[a-zà-ÿ']+/g) ?? []) {
		if (DUTCH_MARKERS.has(word)) dutch++;
		if (ENGLISH_MARKERS.has(word)) english++;
	}
	if (dutch === english) return undefined;
	return dutch > english ? "Dutch" : "English";
}

export function otherLanguage(language: Language): Language {
	return language === "Dutch" ? "English" : "Dutch";
}
