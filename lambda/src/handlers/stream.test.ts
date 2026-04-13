import { SSMClient } from '@aws-sdk/client-ssm';
import { handleStream, clearCache } from './stream';

jest.mock('@aws-sdk/client-ssm');
jest.mock('../config', () => ({
  config: {
    AWS_REGION: 'eu-west-1',
    IVS_PLAYBACK_URL: 'https://test.example.cloudfront.net/hls/master.m3u8',
    IVS_DVR_ENABLED: 'true',
    SSM_STREAM_STATE_PARAM: '/streamline/test/stream-state',
  },
}));
jest.mock('../logger', () => ({
  log: { info: jest.fn(), warn: jest.fn(), error: jest.fn() },
}));

const mockSend = jest.fn();
(SSMClient as jest.Mock).mockImplementation(() => ({ send: mockSend }));

beforeEach(() => {
  clearCache();
  mockSend.mockReset();
});

describe('handleStream', () => {
  it('returns idle status when SSM parameter does not exist', async () => {
    const err = Object.assign(new Error('ParameterNotFound'), { name: 'ParameterNotFound' });
    mockSend.mockRejectedValueOnce(err);

    const result = await handleStream();

    expect(result.status).toBe('idle');
    expect(result.playbackUrl).toBe('https://test.example.cloudfront.net/hls/master.m3u8');
  });

  it('returns live status when SSM has live state', async () => {
    mockSend.mockResolvedValueOnce({
      Parameter: {
        Value: JSON.stringify({ status: 'live', updatedAt: '2024-01-01T00:00:00.000Z' }),
      },
    });

    const result = await handleStream();

    expect(result.status).toBe('live');
    expect(result.dvr.enabled).toBe(true);
    expect(result.dvr.windowSeconds).toBe(14400);
  });

  it('returns idle when SSM value has idle state', async () => {
    mockSend.mockResolvedValueOnce({
      Parameter: {
        Value: JSON.stringify({ status: 'idle', updatedAt: '2024-01-01T00:00:00.000Z' }),
      },
    });

    const result = await handleStream();

    expect(result.status).toBe('idle');
  });

  it('caches the response within the TTL', async () => {
    mockSend.mockResolvedValueOnce({
      Parameter: {
        Value: JSON.stringify({ status: 'live', updatedAt: '2024-01-01T00:00:00.000Z' }),
      },
    });

    await handleStream();
    await handleStream(); // should hit cache

    expect(mockSend).toHaveBeenCalledTimes(1);
  });

  it('re-fetches after clearCache', async () => {
    mockSend
      .mockResolvedValueOnce({
        Parameter: { Value: JSON.stringify({ status: 'live', updatedAt: '' }) },
      })
      .mockResolvedValueOnce({
        Parameter: { Value: JSON.stringify({ status: 'idle', updatedAt: '' }) },
      });

    const first = await handleStream();
    clearCache();
    const second = await handleStream();

    expect(first.status).toBe('live');
    expect(second.status).toBe('idle');
    expect(mockSend).toHaveBeenCalledTimes(2);
  });

  it('re-throws unexpected SSM errors', async () => {
    const err = Object.assign(new Error('InternalServerError'), { name: 'InternalServerError' });
    mockSend.mockRejectedValueOnce(err);

    await expect(handleStream()).rejects.toThrow('InternalServerError');
  });
});
