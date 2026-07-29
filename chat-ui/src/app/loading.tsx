import { Skeleton } from '@/components/ui/skeleton';

export default function Loading() {
  return (
    <div className="bg-black min-h-screen p-8">
      <div className="grid grid-cols-3 gap-4 max-w-3xl mx-auto">
        {[...Array(6)].map((_, i) => (
          <Skeleton key={i} className="h-24 bg-[#1A1A1A] rounded-lg" />
        ))}
      </div>
    </div>
  );
}
