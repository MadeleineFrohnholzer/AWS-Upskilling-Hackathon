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
    const rawPayload = new TextDecoder().decode(response.Payload);
    console.log('Lambda raw response:', rawPayload, 'FunctionError:', response.FunctionError);

    if (response.FunctionError) {
      console.error('Lambda function error:', rawPayload);
      return NextResponse.json({ error: 'Upload service error' }, { status: 502 });
    }

    const payload = JSON.parse(rawPayload);
    const parsed = typeof payload.body === 'string' ? JSON.parse(payload.body) : payload;
    console.log('Lambda parsed response:', parsed);

    if (parsed.statusCode && parsed.statusCode !== 200) {
      return NextResponse.json({ error: parsed.errors?.join(', ') ?? 'Upload service error' }, { status: parsed.statusCode });
    }

    if (!parsed.upload_url) {
      console.error('Missing upload_url in Lambda response:', parsed);
      return NextResponse.json({ error: 'No upload URL returned' }, { status: 502 });
    }

    return NextResponse.json({ url: parsed.upload_url });
  } catch (error) {
    console.error('Upload URL error:', error);
    return NextResponse.json({ error: 'Failed to get upload URL' }, { status: 500 });
  }
}
