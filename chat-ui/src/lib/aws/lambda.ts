import { LambdaClient } from '@aws-sdk/client-lambda';

let client: LambdaClient | null = null;

export function getLambdaClient(): LambdaClient {
  if (!client) {
    client = new LambdaClient({
      region: process.env.AWS_REGION ?? 'eu-west-1',
    });
  }
  return client;
}
