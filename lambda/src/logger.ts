type Level = 'INFO' | 'WARN' | 'ERROR';

function emit(level: Level, message: string, fields?: Record<string, unknown>): void {
  process.stdout.write(
    JSON.stringify({ level, message, timestamp: new Date().toISOString(), ...fields }) + '\n',
  );
}

export const log = {
  info:  (msg: string, fields?: Record<string, unknown>) => emit('INFO',  msg, fields),
  warn:  (msg: string, fields?: Record<string, unknown>) => emit('WARN',  msg, fields),
  error: (msg: string, fields?: Record<string, unknown>) => emit('ERROR', msg, fields),
};
