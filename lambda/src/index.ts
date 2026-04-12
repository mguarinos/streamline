import type { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { handleHealth } from './handlers/health';
import { handleStream } from './handlers/stream';

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

function internalError(): APIGatewayProxyResultV2 {
  return {
    statusCode: 500,
    headers: BASE_HEADERS,
    body: JSON.stringify({ error: 'internal server error' }),
  };
}

export const handler = async (event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> => {
  const path = event.rawPath;

  try {
    if (path === '/health' || path === '/api/health') {
      return ok(handleHealth());
    }

    if (path === '/api/stream') {
      return ok(await handleStream());
    }

    return notFound();
  } catch (err) {
    console.error('Unhandled error:', err);
    return internalError();
  }
};
