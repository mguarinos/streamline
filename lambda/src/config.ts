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
  // When empty (local dev), X-Origin-Verify checking is disabled.
  // In production this is set by Terraform to the CloudFront shared secret.
  ORIGIN_VERIFY_SECRET: optionalEnv('ORIGIN_VERIFY_SECRET', ''),
} as const;
