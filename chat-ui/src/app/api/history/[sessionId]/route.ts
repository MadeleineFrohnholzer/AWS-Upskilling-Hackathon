import { NextRequest, NextResponse } from 'next/server';

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ sessionId: string }> }
) {
  const { sessionId } = await params;

  if (!process.env.DYNAMODB_TABLE_NAME) {
    return NextResponse.json({ items: [] });
  }

  try {
    const { getDynamoClient } = await import('@/lib/aws/dynamodb');
    const { QueryCommand } = await import('@aws-sdk/lib-dynamodb');

    const client = getDynamoClient();
    const result = await client.send(new QueryCommand({
      TableName: process.env.DYNAMODB_TABLE_NAME,
      KeyConditionExpression: 'sessionId = :sid',
      ExpressionAttributeValues: { ':sid': sessionId },
      ScanIndexForward: true,
    }));

    return NextResponse.json({ items: result.Items ?? [] });
  } catch (error) {
    console.error('History error:', error);
    return NextResponse.json({ items: [] });
  }
}
