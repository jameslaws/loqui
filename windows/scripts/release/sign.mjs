// Signs one file through Microsoft's Artifact Signing, then checks the
// signature, for when the signing switch is on (repository variable
// WINDOWS_SIGNING = on). Tauri calls it for the app, the uninstaller and each
// installer (bundle.windows.signCommand); windows-release.yml calls it for the
// speech engine's DLLs. It stops the release with the file's name when there
// is no signing account to sign with, so nothing unsigned is ever published
// with the switch on (SIGN-02).
//
// The login is federated (azure/login in the workflow, no stored secret); the
// account comes from LOQUI_SIGNING_DLIB (Microsoft's signing library) and
// LOQUI_SIGNING_METADATA (its account settings), which the workflow writes.
//
// Usage: node scripts/release/sign.mjs <file>
import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";

const file = process.argv[2];
const {
  LOQUI_SIGNING_DLIB: dlib,
  LOQUI_SIGNING_METADATA: metadata,
  LOQUI_SIGNTOOL: signtool = "signtool.exe",
} = process.env;

if (!file) {
  console.error("Usage: node scripts/release/sign.mjs <file>");
  process.exit(1);
}
if (!dlib || !metadata || !existsSync(dlib) || !existsSync(metadata)) {
  console.error(
    `Signing is switched on, but no signing account is connected, so ${file} can't be signed. Nothing was published.`,
  );
  process.exit(1);
}

const run = (args) => execFileSync(signtool, args, { stdio: "inherit" });
run([
  "sign",
  "/v",
  "/fd",
  "SHA256",
  "/tr",
  "http://timestamp.acs.microsoft.com",
  "/td",
  "SHA256",
  "/dlib",
  dlib,
  "/dmdf",
  metadata,
  file,
]);
try {
  run(["verify", "/pa", file]);
} catch {
  console.error(`${file} isn't validly signed after signing. Nothing was published.`);
  process.exit(1);
}
