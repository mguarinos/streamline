import type { APIGatewayProxyEventV2 } from 'aws-lambda';

jest.mock('./handlers/health', () => ({
  handleHealth: jest.fn(() => ({ status: 'ok', version: '1.0.0', region: 'eu-west-1' })),
}));

jest.mock('./handlers/stream', () => ({
  handleStream: jest.fn(async () => ({
    playbackUrl: 'https://test.example.cloudfront.net/hls/master.m3u8',
    status: 'idle',
    dvr: { enabled: true, windowSeconds: 14400 },
  })),
}));

jest.mock('./handlers/state', () => ({
  handleStateChange: jest.fn(async () => undefined),
}));

// Inline the initial config values; the factory runs at hoist time so
// we cannot reference any const declared in this module here.
jest.mock('./config', () => ({
  config: {
    AWS_REGION: 'eu-west-1',
    ORIGIN_VERIFY_SECRET: '',
  },
}));

jest.mock('./logger', () => ({
  log: { info: jest.fn(), warn: jest.fn(), error: jest.fn() },
}));

// Grab a reference to the mocked config object so tests can mutate it.
// eslint-disable-next-line @typescript-eslint/no-require-imports
const mockConfig = (require('./config') as { config: { AWS_REGION: string; ORIGIN_VERIFY_SECRET: string } }).config;

import { handler } from './index';
import { handleStateChange } from './handlers/state';

function makeEvent(rawPath: string, headers: Record<string, string> = {}): APIGatewayProxyEventV2 {
  return { rawPath, headers, requestContext: {} } as unknown as APIGatewayProxyEventV2;
}

describe('HTTP routing', () => {
  it('routes /api/health to 200', async () => {
    const res = await handler(makeEvent('/api/health'));
    expect(res).toBeDefined();
    expect((res as { statusCode: number }).statusCode).toBe(200);
  });

  it('routes /health to 200', async () => {
    const res = await handler(makeEvent('/health'));
    expect((res as { statusCode: number }).statusCode).toBe(200);
  });

  it('routes /api/stream to 200', async () => {
    const res = await handler(makeEvent('/api/stream'));
    expect((res as { statusCode: number }).statusCode).toBe(200);
  });

  it('returns 404 for an unknown path', async () => {
    const res = await handler(makeEvent('/not-a-real-path'));
    expect((res as { statusCode: number }).statusCode).toBe(404);
  });
});

describe('X-Origin-Verify', () => {
  afterEach(() => {
    mockConfig.ORIGIN_VERIFY_SECRET = '';
  });

  it('skips check when ORIGIN_VERIFY_SECRET is empty', async () => {
    mockConfig.ORIGIN_VERIFY_SECRET = '';
    const res = await handler(makeEvent('/api/health'));
    expect((res as { statusCode: number }).statusCode).toBe(200);
  });

  it('returns 403 when header is missing and secret is set', async () => {
    mockConfig.ORIGIN_VERIFY_SECRET = 'expected-secret';
    const res = await handler(makeEvent('/api/health'));
    expect((res as { statusCode: number }).statusCode).toBe(403);
  });

  it('returns 403 when header value is wrong', async () => {
    mockConfig.ORIGIN_VERIFY_SECRET = 'expected-secret';
    const res = await handler(makeEvent('/api/health', { 'x-origin-verify': 'wrong-value' }));
    expect((res as { statusCode: number }).statusCode).toBe(403);
  });

  it('allows request when header matches the secret', async () => {
    mockConfig.ORIGIN_VERIFY_SECRET = 'expected-secret';
    const res = await handler(makeEvent('/api/health', { 'x-origin-verify': 'expected-secret' }));
    expect((res as { statusCode: number }).statusCode).toBe(200);
  });
});

describe('EventBridge routing', () => {
  it('routes IVS stream state change event to handleStateChange', async () => {
    const ivsEvent = {
      source: 'aws.ivs' as const,
      'detail-type': 'IVS Stream State Change',
      detail: { event_name: 'Stream Start' },
    };

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    await handler(ivsEvent as any);

    expect(handleStateChange).toHaveBeenCalledWith(ivsEvent);
  });

  it('returns void for EventBridge invocations', async () => {
    const ivsEvent = {
      source: 'aws.ivs' as const,
      'detail-type': 'IVS Stream State Change',
      detail: { event_name: 'Stream End' },
    };

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const result = await handler(ivsEvent as any);

    expect(result).toBeUndefined();
  });
});
