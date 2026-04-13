import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';
import { config } from '../config';
import { log } from '../logger';

const DVR_WINDOW_SECONDS = 14400; // IVS maximum: 4 hours
const CACHE_TTL_MS = 10_000;

interface StreamState {
  status: 'live' | 'idle';
  updatedAt: string;
}

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

const ssmClient = new SSMClient({ region: config.AWS_REGION });

// Local dev override — set STREAM_STATUS_MOCK=idle (or live) in .env to
// bypass the SSM call entirely. Without real AWS credentials the SSM call
// would throw, so this keeps `npm run dev` usable without cloud access.
const statusMock = process.env.STREAM_STATUS_MOCK as 'live' | 'idle' | undefined;

export function clearCache(): void {
  cache = null;
}

async function fetchStreamState(): Promise<'live' | 'idle'> {
  if (statusMock === 'live' || statusMock === 'idle') {
    return statusMock;
  }

  try {
    const { Parameter } = await ssmClient.send(
      new GetParameterCommand({ Name: config.SSM_STREAM_STATE_PARAM }),
    );
    if (!Parameter?.Value) return 'idle';
    const state = JSON.parse(Parameter.Value) as StreamState;
    return state.status === 'live' ? 'live' : 'idle';
  } catch (err) {
    // Parameter doesn't exist yet — stream has never been live
    if ((err as { name?: string }).name === 'ParameterNotFound') {
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

  const status = await fetchStreamState();
  log.info('stream state fetched from SSM', { status });

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
