import { getInput as ghactionsGetInput, getBooleanInput as ghactionsGetBooleanInput, getMultilineInput as ghactionsGetMultilineInput } from "@actions/core";
import yaml from "yaml";
import which from "which";
import { executeChildProcess, type ChildProcessResult } from "./execute.js";
function getBooleanInputRequire(name: string): boolean {
	return ghactionsGetBooleanInput(name, {
		required: true,
		trimWhitespace: false
	});
}
function getRegExpInputOptional(name: string): RegExp | undefined {
	const raw: string = ghactionsGetInput(name, { trimWhitespace: false }).split(/\r?\n/gu).filter((value: string): boolean => {
		return (value.length > 0);
	}).join("|");
	return ((raw.length > 0) ? new RegExp(raw, "u") : undefined);
}
interface DSOListElement {
	name: string;
	description: string;
	postpone: number;
	apt?: string[];
	chocolatey?: string[];
	homebrew?: string[];
	npm?: string[];
	pipx?: string[];
	powershellGet?: string[];
	wmic?: string[];
	env?: string[];
	pathLinux?: string[];
	pathMacOS?: string[];
	pathWindows?: string[];
}
let inputAptClean: boolean = getBooleanInputRequire("apt_clean");
let inputAptEnable: boolean = getBooleanInputRequire("apt_enable");
let inputAptPrune: boolean = getBooleanInputRequire("apt_prune");
let inputChocolateyEnable: boolean = getBooleanInputRequire("chocolatey_enable");
let inputDockerClean: boolean = getBooleanInputRequire("docker_clean");
const inputDockerExclude: RegExp | undefined = getRegExpInputOptional("docker_exclude");
const inputDockerInclude: RegExp | undefined = getRegExpInputOptional("docker_include");
let inputDockerPrune: boolean = getBooleanInputRequire("docker_prune");
let inputFsEnable: boolean = getBooleanInputRequire("fs_enable");
const inputGeneralExclude: RegExp | undefined = getRegExpInputOptional("general_exclude");
const inputGeneralInclude: RegExp | undefined = getRegExpInputOptional("general_include");
let inputHomebrewClean: boolean = getBooleanInputRequire("homebrew_clean");
let inputHomebrewEnable: boolean = getBooleanInputRequire("homebrew_enable");
let inputHomebrewPrune: boolean = getBooleanInputRequire("homebrew_prune");
let inputNpmClean: boolean = getBooleanInputRequire("npm_clean");
let inputNpmEnable: boolean = getBooleanInputRequire("npm_enable");
let inputNpmPrune: boolean = getBooleanInputRequire("npm_prune");
let inputOperateAsync: boolean = getBooleanInputRequire("operate_async");
let inputOperateSudo: boolean = getBooleanInputRequire("operate_sudo");
let inputOsSwap: boolean = getBooleanInputRequire("os_swap");
let inputPipxEnable: boolean = getBooleanInputRequire("pipx_enable");
let inputWmicEnable: boolean = getBooleanInputRequire("wmic_enable");
if (!inputAptEnable && !inputChocolateyEnable && !inputFsEnable && !inputHomebrewEnable && !inputNpmEnable && !inputPipxEnable && !inputWmicEnable) {
	inputAptEnable = true;
	inputChocolateyEnable = true;
	inputFsEnable = true;
	inputHomebrewEnable = true;
	inputNpmEnable = true;
	inputPipxEnable = true;
	inputWmicEnable = true;
}
interface DSORegistryMeta {
	isExist: boolean;
	list?: () => Promise<ChildProcessResult>;
	remove: (packages: string[], sudo: boolean) => Promise<ChildProcessResult>;
}
const registries: Record<string, DSORegistryMeta> = {
	apt: {
		isExist: typeof await which("apt-get", { nothrow: true }) === "string",
		remove: (packages: string[], sudo: boolean): Promise<ChildProcessResult> => {
			const command: string[] = ["apt-get", "--assume-yes", "remove", ...packages, "*>&1"];
			if (sudo) {
				return executeChildProcess(["sudo", ...command]);
			}
			return executeChildProcess(command);
		}
	},
	chocolatey: {
		isExist: typeof await which("choco", { nothrow: true }) === "string",
		remove: (packages: string[], sudo: boolean): Promise<ChildProcessResult> => {
			const command: string[] = ["choco", "uninstall", "remove", ...packages, "*>&1"];
			if (sudo) {
				return executeChildProcess(["sudo", ...command]);
			}
			return executeChildProcess(command);
		}
	}
};
