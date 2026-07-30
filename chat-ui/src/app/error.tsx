'use client';

import { useEffect } from 'react';
import { Button } from '@/components/ui/button';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <div className="flex flex-col items-center justify-center h-screen bg-black gap-6">
      <h2 className="text-white text-2xl font-semibold">Something went wrong</h2>
      <p className="text-[#888888] text-sm">{error.message}</p>
      <Button
        onClick={reset}
        className="bg-[#A100FF] hover:bg-[#8A00E0] text-white"
      >
        Try again
      </Button>
    </div>
  );
}
