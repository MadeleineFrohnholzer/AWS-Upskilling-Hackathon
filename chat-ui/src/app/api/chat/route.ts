import { NextRequest, NextResponse } from 'next/server';
import { headers } from 'next/headers';
import { getUserFromRequest } from '@/lib/auth';
import type { Citation } from '@/types/chat';

export async function POST(req: NextRequest) {
  const { sessionId, message } = await req.json();

  if (!process.env.BEDROCK_AGENT_ID) {
    return NextResponse.json({
      message: `Mock response: ${message}`,
      citations: [] as Citation[],
    });
  }

  try {
    const { getBedrockClient } = await import('@/lib/aws/bedrock');
    const { InvokeAgentCommand } = await import('@aws-sdk/client-bedrock-agent-runtime');
    const { getDynamoClient } = await import('@/lib/aws/dynamodb');
    const { PutCommand } = await import('@aws-sdk/lib-dynamodb');

    const headersList = await headers();
    const userEmail = getUserFromRequest(headersList) ?? 'unknown';

    const client = getBedrockClient();
    const command = new InvokeAgentCommand({
      agentId: process.env.BEDROCK_AGENT_ID!,
      agentAliasId: process.env.BEDROCK_AGENT_ALIAS_ID!,
      sessionId,
      inputText: message,
      enableTrace: true,
    });

    const response = await client.send(command);
    let responseText = '';
    const citations: Citation[] = [];

    if (response.completion) {
      for await (const event of response.completion) {
        if (event.chunk?.bytes) {
          responseText += new TextDecoder().decode(event.chunk.bytes);
        }
        if (event.trace?.trace?.orchestrationTrace?.observation?.knowledgeBaseLookupOutput) {
          const refs =
            event.trace.trace.orchestrationTrace.observation.knowledgeBaseLookupOutput
              .retrievedReferences ?? [];
          for (const ref of refs) {
            citations.push({
              source: ref.location?.s3Location?.uri ?? 'unknown',
              excerpt: ref.content?.text?.slice(0, 200),
            });
          }
        }
      }
    }

    // Persist history — non-fatal: don't let DynamoDB errors break the chat response
    if (process.env.DYNAMODB_TABLE_NAME) {
      const dynamo = getDynamoClient();
      const now = new Date().toISOString();
      Promise.all([
        dynamo.send(new PutCommand({
          TableName: process.env.DYNAMODB_TABLE_NAME,
          Item: {
            sessionId,
            timestamp: now,
            role: 'user',
            message,
            citations: [],
            userEmail,
            sessionTitle: message.slice(0, 80),
          },
        })),
        dynamo.send(new PutCommand({
          TableName: process.env.DYNAMODB_TABLE_NAME,
          Item: {
            sessionId,
            timestamp: new Date(Date.now() + 1).toISOString(),
            role: 'assistant',
            message: responseText,
            citations,
            userEmail,
          },
        })),
      ]).catch((err) => console.error('DynamoDB write error:', err));
    }

    return NextResponse.json({ message: responseText, citations });
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    console.error('Chat error:', detail, error);
    return NextResponse.json({ error: detail }, { status: 500 });
  }
}
