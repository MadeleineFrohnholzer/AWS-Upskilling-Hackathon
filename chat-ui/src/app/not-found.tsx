import Link from 'next/link';
import { AccentureMark } from '@/components/brand/AccentureMark';
import { Button } from '@/components/ui/button';

export default function NotFound() {
  return (
    <div className="flex flex-col items-center justify-center h-screen bg-black gap-6">
      <AccentureMark size={64} />
      <h1 className="text-white text-2xl font-semibold">Page not found</h1>
      <p className="text-[#888888] text-sm">The page you&apos;re looking for doesn&apos;t exist.</p>
      <Button asChild className="bg-[#A100FF] hover:bg-[#8A00E0] text-white">
        <Link href="/">Go back home</Link>
      </Button>
    </div>
  );
}
