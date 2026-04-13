function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

function optionalEnv(name: string, defaultValue: string): string {
  return process.env[name] ?? defaultValue;
}

export const config = {
  IVS_PLAYBACK_URL: requireEnv('IVS_PLAYBACK_URL'),
  IVS_DVR_ENABLED: optionalEnv('IVS_DVR_ENABLED', 'true'),
  AWS_REGION: requireEnv('AWS_REGION'),
  SSM_STREAM_STATE_PARAM: requireEnv('SSM_STREAM_STATE_PARAM'),
} as const;
