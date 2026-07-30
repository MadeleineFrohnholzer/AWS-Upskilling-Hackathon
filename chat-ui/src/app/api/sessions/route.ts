import { NextResponse } from 'next/server';
import { headers } from 'next/headers';
import { getUserFromRequest } from '@/lib/auth';

export async function GET() {
  if (!process.env.DYNAMODB_TABLE_NAME) {
    return NextResponse.json({ sessions: [] });
  }

  try {
    const { getDynamoClient } = await import('@/lib/aws/dynamodb');
    const { QueryCommand } = await import('@aws-sdk/lib-dynamodb');

    const headersList = await headers();
    const userEmail = getUserFromRequest(headersList);
    if (!userEmail) {
      return NextResponse.json({ sessions: [] });
    }

    const client = getDynamoClient();
    const result = await client.send(new QueryCommand({
      TableName: process.env.DYNAMODB_TABLE_NAME,
      IndexName: 'userEmail-index',
      KeyConditionExpression: 'userEmail = :email',
      ExpressionAttributeValues: { ':email': userEmail },
      ScanIndexForward: false,
    }));

    const sessions = (result.Items ?? []).map((item) => ({
      sessionId: item.sessionId,
      title: item.sessionTitle ?? 'Untitled',
      lastMessageAt: item.timestamp,
    }));

    return NextResponse.json({ sessions });
  } catch (error) {
    console.error('Sessions error:', error);
    return NextResponse.json({ sessions: [] });
  }
}
