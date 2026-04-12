/**
 * local.ts — minimal local dev server (no Express, built-in http only)
 *
 * Usage:
 *   cp lambda/.env.example lambda/.env
 *   npm run dev
 *
 * The /api/stream endpoint returns status "idle" locally because
 * IVS_CHANNEL_ARN in .env.example is fake — ResourceNotFoundException
 * is caught and mapped to idle gracefully. The player still renders
 * using the public HLS stream set in IVS_PLAYBACK_URL.
 */

import * as fs from 'fs';
import * as http from 'http';
import * as path from 'path';

// ── Load .env ─────────────────────────────────────────────────────────────────
// Must happen before importing ./index so config.ts sees the vars at load time.
// Dynamic import below is intentional — static imports are hoisted by tsc and
// would run before this block even though they appear later in the source.

const envPath = path.join(__dirname, '..', '.env');

if (fs.existsSync(envPath)) {
  const lines = fs.readFileSync(envPath, 'utf-8').split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx === -1) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const value = trimmed.slice(eqIdx + 1).trim();
    process.env[key] = value;
  }
}

// ── Server ────────────────────────────────────────────────────────────────────

const PORT = 3001;

async function main(): Promise<void> {
  // Dynamic import runs after env vars are set — not hoisted like static imports.
  const { handler } = await import('./index');

  const server = http.createServer(async (req, res) => {
    const rawPath = (req.url ?? '/').split('?')[0];

    // Minimal Lambda event — only rawPath is used by the router in index.ts.
    const event = { rawPath } as Parameters<typeof handler>[0];

    const result = await handler(event, {} as never, () => undefined) as {
      statusCode: number;
      headers: Record<string, string>;
      body: string;
    };

    console.log(`${req.method} ${req.url} → ${result.statusCode}`);

    res.writeHead(result.statusCode, result.headers ?? {});
    res.end(result.body ?? '');
  });

  server.listen(PORT, () => {
    console.log(`Streamline local server running at http://localhost:${PORT}`);
    console.log('  GET http://localhost:3001/api/health');
    console.log('  GET http://localhost:3001/api/stream');
  });
}

main().catch(console.error);
