import { handleHealth } from './health';

jest.mock('fs', () => ({
  readFileSync: jest.fn(() => '1.2.3\n'),
}));

jest.mock('../config', () => ({
  config: { AWS_REGION: 'eu-west-1' },
}));

describe('handleHealth', () => {
  it('returns status ok', () => {
    expect(handleHealth().status).toBe('ok');
  });

  it('trims the version string read from disk', () => {
    expect(handleHealth().version).toBe('1.2.3');
  });

  it('includes the configured region', () => {
    expect(handleHealth().region).toBe('eu-west-1');
  });
});
