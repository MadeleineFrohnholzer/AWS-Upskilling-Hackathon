'use client';

import Link from 'next/link';

export default function NotFound() {
  return (
    <div className="flex flex-col items-center justify-center h-screen bg-black gap-6">
      <svg width={64} height={64} viewBox="0 0 24 24" fill="none" aria-hidden>
        <path d="M6 4l12 8-12 8" stroke="#A100FF" strokeWidth="3"
              strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      <h1 className="text-white text-2xl font-semibold">Page not found</h1>
      <p className="text-[#888888] text-sm">The page you&apos;re looking for doesn&apos;t exist.</p>
      <Link
        href="/"
        className="px-4 py-2 bg-[#A100FF] hover:bg-[#8A00E0] text-white rounded-md text-sm font-medium transition-colors"
      >
        Go back home
      </Link>
    </div>
  );
}
