import { NextResponse } from 'next/server';
import { headers } from 'next/headers';
import { getUserFromRequest } from '@/lib/auth';

export async function GET() {
  const headersList = await headers();
  const email = getUserFromRequest(headersList) ?? process.env.DEV_USER_EMAIL ?? 'dev@local';
  return NextResponse.json({ email });
}
