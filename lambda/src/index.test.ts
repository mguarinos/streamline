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

jest.mock('./logger', () => ({
  log: { info: jest.fn(), warn: jest.fn(), error: jest.fn() },
}));

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
