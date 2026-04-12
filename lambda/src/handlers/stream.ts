import { IvsClient, GetStreamCommand } from '@aws-sdk/client-ivs';
import { config } from '../config';

const DVR_WINDOW_SECONDS = 14400; // IVS maximum: 4 hours
const CACHE_TTL_MS = 10_000;

interface StreamResponse {
  playbackUrl: string;
  status: 'live' | 'idle';
  dvr: {
    enabled: boolean;
    windowSeconds: number;
  };
}

interface Cache {
  response: StreamResponse;
  fetchedAt: number;
}

let cache: Cache | null = null;

const ivsClient = new IvsClient({ region: config.AWS_REGION });

async function fetchStreamStatus(): Promise<'live' | 'idle'> {
  try {
    const { stream } = await ivsClient.send(
      new GetStreamCommand({ channelArn: config.IVS_CHANNEL_ARN }),
    );
    return stream?.state === 'LIVE' ? 'live' : 'idle';
  } catch (err) {
    // Use .name check rather than instanceof — safer across module boundaries
    // and consistent with how the AWS SDK v3 surfaces service errors.
    if ((err as { name?: string }).name === 'ResourceNotFoundException') {
      return 'idle';
    }
    throw err;
  }
}

export async function handleStream(): Promise<StreamResponse> {
  const now = Date.now();

  if (cache !== null && now - cache.fetchedAt < CACHE_TTL_MS) {
    return cache.response;
  }

  const status = await fetchStreamStatus();

  const response: StreamResponse = {
    playbackUrl: config.IVS_PLAYBACK_URL,
    status,
    dvr: {
      enabled: config.IVS_DVR_ENABLED === 'true',
      windowSeconds: DVR_WINDOW_SECONDS,
    },
  };

  cache = { response, fetchedAt: now };

  return response;
}
