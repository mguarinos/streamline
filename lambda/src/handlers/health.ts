import * as fs from 'fs';
import * as path from 'path';
import { config } from '../config';

interface HealthResponse {
  status: 'ok';
  version: string;
  region: string;
}

function readVersion(): string {
  const versionPath = path.join(__dirname, '..', 'VERSION');
  return fs.readFileSync(versionPath, 'utf-8').trim();
}

export function handleHealth(): HealthResponse {
  return {
    status: 'ok',
    version: readVersion(),
    region: config.AWS_REGION,
  };
}
