import { mkdir as fsMkdir, readdir as fsReaddir, rm as fsRm, writeFile as fsWriteFile } from "node:fs/promises";
import { dirname as pathDirname, join as pathJoin } from "node:path";
import { fileURLToPath } from "node:url";
import ncc from "@vercel/ncc";
const workspace = pathDirname(fileURLToPath(import.meta.url));
const directoryInput = pathJoin(workspace, "temp");
const directoryOutput = pathJoin(workspace, "dist");
const scripts = new Set([
	"main.js"
]);

// Initialize output directory.
await fsMkdir(directoryOutput, { recursive: true });
for (const fileName of await fsReaddir(directoryOutput)) {
	await fsRm(pathJoin(directoryOutput, fileName), { maxRetries: 4, recursive: true });
}

// Create bundle.
for (const script of scripts.values()) {
	const { code } = await ncc(pathJoin(directoryInput, script), {
		assetBuilds: false,
		cache: false,
		debugLog: false,
		license: "",
		minify: true,
		quiet: false,
		sourceMap: false,
		sourceMapRegister: false,
		target: "es2022",
		v8cache: false,
		watch: false
	});
	await fsWriteFile(pathJoin(directoryOutput, script), code, { encoding: "utf8" });
}
