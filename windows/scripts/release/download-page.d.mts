// Types for download-page.mjs, for the checks that read the Windows download page.
export function downloadPage(
  release: {
    base: string;
    signed: boolean;
    manifests: { version: string; arch: string; setup: { file: string; size: number } }[];
  } | null,
): string;
