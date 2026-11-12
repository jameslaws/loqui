// `pnpm build`: loqui's two installers for this PC's kind of Windows, into
// target/installers:
//
//   loqui-setup-<version>-<arch>.exe   the full installer, with the speech
//                                      model: what people download
//   loqui-update-<version>-<arch>.exe  the update installer, without the
//                                      model, and its .sig: what the update
//                                      lists point at
//   loqui-<version>-<arch>.json        both files' names, sizes and SHA-256,
//                                      and the update's signature
//
// The update installer needs loqui's update key to sign it
// (TAURI_SIGNING_PRIVATE_KEY); without one only the full installer is made.
// Extra Tauri settings pass through: pnpm build --config <json or file>.
// --full-config adds settings to the full installer only; --out <folder> puts
// the files somewhere other than target/installers.
//
// Usage: node scripts/release/build.mjs [--config <json or file>]... [--full-config <json or file>] [--out <folder>]
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
  createReadStream,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  renameSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { join, resolve } from "node:path";
import { pipeline } from "node:stream/promises";

const windowsDir = join(import.meta.dirname, "..", "..");
const tauriDir = join(windowsDir, "src-tauri");
const models = join(tauriDir, "models");
const bundle = join(windowsDir, "target", "release", "bundle", "nsis");
let out = join(windowsDir, "target", "installers");
const arch = process.arch === "arm64" ? "arm64" : "x64";

const passed = [];
const fullOnly = [];
for (let i = 2; i < process.argv.length; i++) {
  if (process.argv[i] === "--config" && process.argv[i + 1]) passed.push("--config", process.argv[++i]);
  else if (process.argv[i] === "--full-config" && process.argv[i + 1]) fullOnly.push("--config", process.argv[++i]);
  else if (process.argv[i] === "--out" && process.argv[i + 1]) out = resolve(process.argv[++i]);
  else if (process.argv[i] !== "--") throw new Error(`build.mjs doesn't know ${process.argv[i]}`);
}

async function sha256(file) {
  const hash = createHash("sha256");
  await pipeline(createReadStream(file), hash);
  return hash.digest("hex");
}

const modelFiles = [
  "parakeet/encoder.int8.onnx",
  "parakeet/decoder.int8.onnx",
  "parakeet/joiner.int8.onnx",
  "parakeet/tokens.txt",
  "silero_vad.onnx",
];
for (const file of modelFiles) {
  if (!existsSync(join(models, file))) {
    console.error(`No speech model at src-tauri/models/${file}. Run pnpm fetch:speech first.`);
    process.exit(1);
  }
}

// The model's version for the installers: one hash over its files, so the
// full installer copies it again only when it really changed.
const each = [];
for (const file of modelFiles) each.push(`${file} ${await sha256(join(models, file))}`);
const modelVersion = createHash("sha256").update(each.join("\n")).digest("hex");
writeFileSync(join(models, "version.nsh"), `!define LOQUI_MODEL_VERSION "${modelVersion}"\n`);

/** Build one installer with these settings and move it to `name`; returns its path. */
function build(config, name, extra = []) {
  rmSync(bundle, { recursive: true, force: true });
  execFileSync(
    "pnpm",
    ["exec", "tauri", "build", "--bundles", "nsis", "--config", join(tauriDir, config), ...passed, ...extra],
    {
      cwd: windowsDir,
      stdio: "inherit",
      shell: process.platform === "win32",
    },
  );
  const made = readdirSync(bundle).find((f) => f.endsWith("-setup.exe"));
  if (!made) throw new Error(`Tauri made no installer in ${bundle}`);
  // Tauri names it loqui_<version>_<arch>-setup.exe.
  const version = made.split("_")[1];
  mkdirSync(out, { recursive: true });
  const file = join(out, name(version));
  renameSync(join(bundle, made), file);
  if (existsSync(join(bundle, `${made}.sig`))) renameSync(join(bundle, `${made}.sig`), `${file}.sig`);
  return { file, version };
}

async function facts(file) {
  return { file: file.split(/[\\/]/).at(-1), size: statSync(file).size, sha256: await sha256(file) };
}

rmSync(out, { recursive: true, force: true });
const full = build("tauri.full.json", (v) => `loqui-setup-${v}-${arch}.exe`, fullOnly);
const manifest = { version: full.version, arch, modelVersion, setup: await facts(full.file) };

if (process.env.TAURI_SIGNING_PRIVATE_KEY) {
  const update = build("tauri.update.json", (v) => `loqui-update-${v}-${arch}.exe`);
  if (update.version !== full.version)
    throw new Error(`the two installers disagree: ${full.version}, ${update.version}`);
  const signature = readFileSync(`${update.file}.sig`, "utf8").trim();
  manifest.update = { ...(await facts(update.file)), signature };
} else {
  console.log("No TAURI_SIGNING_PRIVATE_KEY, so no update installer: only the full installer was made.");
}

writeFileSync(join(out, `loqui-${full.version}-${arch}.json`), `${JSON.stringify(manifest, null, 2)}\n`);
const mb = (bytes) => `${Math.round(bytes / 1048576)} MB`;
console.log(`Full installer: ${manifest.setup.file} (${mb(manifest.setup.size)})`);
if (manifest.update) console.log(`Update installer: ${manifest.update.file} (${mb(manifest.update.size)})`);
