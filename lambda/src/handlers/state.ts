import { SSMClient, PutParameterCommand } from '@aws-sdk/client-ssm';
import { config } from '../config';
import { log } from '../logger';

const ssmClient = new SSMClient({ region: config.AWS_REGION });

export interface IVSStreamStateEvent {
  source: 'aws.ivs';
  'detail-type': string;
  detail: {
    event_name: string;
  };
}

function toStreamStatus(eventName: string): 'live' | 'idle' {
  return eventName === 'Stream Start' ? 'live' : 'idle';
}

export async function handleStateChange(event: IVSStreamStateEvent): Promise<void> {
  const { event_name } = event.detail;
  const status = toStreamStatus(event_name);

  log.info('IVS state change received', { event_name, status });

  await ssmClient.send(
    new PutParameterCommand({
      Name: config.SSM_STREAM_STATE_PARAM,
      Value: JSON.stringify({ status, updatedAt: new Date().toISOString() }),
      Type: 'String',
      Overwrite: true,
    }),
  );

  log.info('stream state written to SSM', { status });
}
