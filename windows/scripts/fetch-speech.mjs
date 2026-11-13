// Downloads the speech engine and model that loqui ships with, each pinned by
// SHA-256, into src-tauri/engine and src-tauri/models (both kept out of git:
// the model is about 640 MB). The build packs them into the installer; the app
// itself never downloads anything.
//
// Usage: node scripts/fetch-speech.mjs [x64|arm64]   (default: this computer)
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
  copyFileSync,
  createReadStream,
  createWriteStream,
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";

const release = "https://github.com/k2-fsa/sherpa-onnx/releases/download";
const engines = {
  "win32-x64": {
    url: `${release}/v2.0.1/sherpa-onnx-v2.0.1-win-x64-shared-MT-Release-no-tts-lib.tar.bz2`,
    sha256: "21da6a8b92d63ca02ad41dbfc120012343aaaec2e5e02b14819c6b4f38004509",
    files: ["sherpa-onnx-c-api.dll", "onnxruntime.dll", "onnxruntime_providers_shared.dll"],
  },
  "win32-arm64": {
    url: `${release}/v2.0.1/sherpa-onnx-v2.0.1-win-arm64-shared-MT-Release-no-tts-lib.tar.bz2`,
    sha256: "b3099bec60e6c3958275e90d0803d837cfe3ad6ed08528f29505d713b3a3e1bb",
    files: ["sherpa-onnx-c-api.dll", "onnxruntime.dll", "onnxruntime_providers_shared.dll"],
  },
  // For trying the engine on a Mac (crates/loqui-speech/examples/transcribe.rs).
  darwin: {
    url: `${release}/v2.0.1/sherpa-onnx-v2.0.1-osx-universal2-shared-no-tts-lib.tar.bz2`,
    sha256: "242b0593a033456e9344a76a11713d1c55da794d0e37eabf6acabaf7beeb2b36",
    files: ["libsherpa-onnx-c-api.dylib", "libonnxruntime.dylib"],
  },
};
const model = {
  url: `${release}/asr-models/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8.tar.bz2`,
  sha256: "1495e91b59d7fc53ddca91f3431758ec99f8fa253fdb0e1e851be0f72b14b0f9",
  files: ["encoder.int8.onnx", "decoder.int8.onnx", "joiner.int8.onnx", "tokens.txt"],
};
const vad = {
  url: `${release}/asr-models/silero_vad.onnx`,
  sha256: "9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6",
};

const windowsDir = join(import.meta.dirname, "..");
const cache = join(windowsDir, ".speech-cache");
const engineDir = join(windowsDir, "src-tauri", "engine");
const modelDir = join(windowsDir, "src-tauri", "models");
const arch = process.argv[2] ?? process.arch;
const platform = process.platform === "darwin" ? "darwin" : `win32-${arch}`;
const engine = engines[platform];
if (!engine) {
  console.error(`No speech engine pinned for ${platform}.`);
  process.exit(1);
}

async function sha256(file) {
  const hash = createHash("sha256");
  await pipeline(createReadStream(file), hash);
  return hash.digest("hex");
}

/** The file at `url`, from the cache if it's there and its checksum matches. */
async function download({ url, sha256: expected }) {
  mkdirSync(cache, { recursive: true });
  const file = join(cache, url.split("/").at(-1));
  if (existsSync(file) && (await sha256(file)) === expected) return file;
  // A dropped connection is retried; a wrong checksum never is.
  for (let attempt = 1; ; attempt++) {
    console.log(`Downloading ${url}`);
    try {
      const response = await fetch(url);
      if (!response.ok || !response.body) throw new Error(`${url}: ${response.status}`);
      await pipeline(Readable.fromWeb(response.body), createWriteStream(file));
      break;
    } catch (error) {
      if (attempt === 3) throw error;
      console.log(`  ${error.cause?.code ?? error.message}; trying again`);
      await new Promise((resolve) => setTimeout(resolve, 5000 * attempt));
    }
  }
  const actual = await sha256(file);
  if (actual !== expected) {
    rmSync(file);
    throw new Error(`${url} has SHA-256 ${actual}, expected ${expected}. Not using it.`);
  }
  return file;
}

/** Unpack an archive and copy the named files from anywhere inside it into `to`. */
function unpack(archive, names, to) {
  const scratch = join(cache, "unpack");
  rmSync(scratch, { recursive: true, force: true });
  mkdirSync(scratch, { recursive: true });
  execFileSync("tar", ["-xjf", archive, "-C", scratch], { stdio: "inherit" });
  const found = execFileSync("tar", ["-tjf", archive], { encoding: "utf8", maxBuffer: 1 << 26 }).split(/\r?\n/);
  mkdirSync(to, { recursive: true });
  for (const name of names) {
    const inside = found.find((path) => path.endsWith(`/${name}`));
    if (!inside) throw new Error(`${archive} has no ${name}`);
    copyFileSync(join(scratch, inside), join(to, name));
  }
  rmSync(scratch, { recursive: true, force: true });
}

const stamp = join(modelDir, ".fetched");
const wanted = [engine.sha256, model.sha256, vad.sha256].join(" ");
if (existsSync(stamp) && readFileSync(stamp, "utf8") === wanted) {
  console.log("The speech engine and model are already in place.");
  process.exit(0);
}
rmSync(engineDir, { recursive: true, force: true });
rmSync(modelDir, { recursive: true, force: true });
unpack(await download(engine), engine.files, engineDir);
unpack(await download(model), model.files, join(modelDir, "parakeet"));
copyFileSync(await download(vad), join(modelDir, "silero_vad.onnx"));
writeFileSync(stamp, wanted);
console.log(`Speech engine (${platform}) and model ready in src-tauri/engine and src-tauri/models.`);
