import type { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { handleHealth } from './handlers/health';
import { handleStream } from './handlers/stream';
import { handleStateChange } from './handlers/state';
import type { IVSStreamStateEvent } from './handlers/state';
import { config } from './config';
import { log } from './logger';

type IncomingEvent = APIGatewayProxyEventV2 | IVSStreamStateEvent;

function isIVSEvent(event: IncomingEvent): event is IVSStreamStateEvent {
  return (event as IVSStreamStateEvent).source === 'aws.ivs';
}

const BASE_HEADERS = {
  'Content-Type': 'application/json',
  'Cache-Control': 'no-cache',
  'Access-Control-Allow-Origin': '*',
};

function ok(body: unknown): APIGatewayProxyResultV2 {
  return { statusCode: 200, headers: BASE_HEADERS, body: JSON.stringify(body) };
}

function notFound(): APIGatewayProxyResultV2 {
  return { statusCode: 404, headers: BASE_HEADERS, body: JSON.stringify({ error: 'not found' }) };
}

function forbidden(): APIGatewayProxyResultV2 {
  return { statusCode: 403, headers: BASE_HEADERS, body: JSON.stringify({ error: 'forbidden' }) };
}

function internalError(): APIGatewayProxyResultV2 {
  return {
    statusCode: 500,
    headers: BASE_HEADERS,
    body: JSON.stringify({ error: 'internal server error' }),
  };
}

export const handler = async (event: IncomingEvent): Promise<APIGatewayProxyResultV2 | void> => {
  // EventBridge invocation — IVS stream state change
  if (isIVSEvent(event)) {
    await handleStateChange(event);
    return;
  }

  const httpEvent = event as APIGatewayProxyEventV2;
  const path = httpEvent.rawPath;

  // X-Origin-Verify: reject requests that bypass CloudFront when secret is set
  const secret = config.ORIGIN_VERIFY_SECRET;
  if (secret !== '') {
    const headerValue = httpEvent.headers?.['x-origin-verify'] ?? '';
    if (headerValue !== secret) {
      log.warn('X-Origin-Verify mismatch', { path });
      return forbidden();
    }
  }

  try {
    if (path === '/health' || path === '/api/health') {
      return ok(handleHealth());
    }

    if (path === '/api/stream') {
      return ok(await handleStream());
    }

    return notFound();
  } catch (err) {
    log.error('Unhandled error', { path, error: String(err) });
    return internalError();
  }
};
