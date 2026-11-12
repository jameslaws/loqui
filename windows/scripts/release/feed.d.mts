// Types for feed.mjs, for the Windows checks that make update lists with it.
export const PLATFORM: { x64: string; arm64: string };
export function feed(release: {
  base: string;
  notes: string;
  manifests: { version: string; arch: string; update: { file: string; size: number; signature: string } }[];
  date?: string;
}): {
  version: string;
  notes: string;
  pub_date: string;
  platforms: Record<string, { url: string; signature: string; size: number }>;
};
