import { AccentureMark } from '@/components/brand/AccentureMark';

export function ThinkingBubble() {
  return (
    <div className="flex gap-3 py-2">
      <div className="flex-shrink-0 mt-1">
        <AccentureMark size={20} />
      </div>
      <div className="flex items-center gap-1 py-2">
        {[0, 200, 400].map((delay) => (
          <span
            key={delay}
            className="w-2 h-2 rounded-full bg-[#A100FF] animate-bounce"
            style={{ animationDelay: `${delay}ms` }}
          />
        ))}
      </div>
    </div>
  );
}
