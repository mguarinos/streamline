/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/*.test.ts'],
  passWithNoTests: true,
  transform: {
    '^.+\\.ts$': ['ts-jest', {
      // Override types for test compilation to add jest globals.
      // tsconfig.json only includes "node" so production code stays clean.
      tsconfig: { types: ['node', 'jest'] },
    }],
  },
};
