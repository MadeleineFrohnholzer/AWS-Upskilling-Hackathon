import { NextRequest, NextResponse } from 'next/server';

export async function POST(req: NextRequest) {
  const body = await req.json();

  if (!process.env.UPLOAD_LAMBDA_NAME) {
    return NextResponse.json({ url: 'https://mock-s3-url.example.com/upload' });
  }

  try {
    const { getLambdaClient } = await import('@/lib/aws/lambda');
    const { InvokeCommand } = await import('@aws-sdk/client-lambda');

    const client = getLambdaClient();
    const lambdaBody = {
      filename: body.fileName,
      Industry: body.industry,
      DocumentType: body.documentType,
      ...(body.useCase && { UseCase: body.useCase }),
      ...(body.client && { Client: body.client }),
    };
    const command = new InvokeCommand({
      FunctionName: process.env.UPLOAD_LAMBDA_NAME,
      Payload: new TextEncoder().encode(JSON.stringify({ body: JSON.stringify(lambdaBody) })),
    });

    const response = await client.send(command);
    const payload = JSON.parse(new TextDecoder().decode(response.Payload));
    const parsed = typeof payload.body === 'string' ? JSON.parse(payload.body) : payload;

    if (parsed.errors) {
      return NextResponse.json({ error: parsed.errors.join(', ') }, { status: 400 });
    }

    return NextResponse.json({ url: parsed.upload_url });
  } catch (error) {
    console.error('Upload URL error:', error);
    return NextResponse.json({ error: 'Failed to get upload URL' }, { status: 500 });
  }
}
