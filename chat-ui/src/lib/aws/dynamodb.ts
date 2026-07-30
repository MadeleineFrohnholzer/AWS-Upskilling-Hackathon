import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';

let docClient: DynamoDBDocumentClient | null = null;

export function getDynamoClient(): DynamoDBDocumentClient {
  if (!docClient) {
    const base = new DynamoDBClient({
      region: process.env.AWS_REGION ?? 'eu-west-1',
    });
    docClient = DynamoDBDocumentClient.from(base);
  }
  return docClient;
}
