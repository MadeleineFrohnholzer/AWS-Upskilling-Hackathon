interface SuggestedPromptsProps {
  onSelect: (prompt: string) => void;
}

const PROMPTS = [
  {
    title: 'Summarise key risks',
    subtitle: 'Get a risk summary from the latest document',
    prompt: 'Summarise the key risks in the latest uploaded document',
  },
  {
    title: 'What changed?',
    subtitle: 'Compare the last two quarterly reports',
    prompt: 'What changed between the last two quarterly reports?',
  },
  {
    title: 'List main clauses',
    subtitle: 'Extract clauses from the most recent contract',
    prompt: 'List the main clauses in the most recent contract',
  },
];

export function SuggestedPrompts({ onSelect }: SuggestedPromptsProps) {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 max-w-2xl w-full">
      {PROMPTS.map((p) => (
        <button
          key={p.prompt}
          onClick={() => onSelect(p.prompt)}
          className="bg-card border border-border rounded-lg p-3 hover:border-[#A100FF] transition-colors cursor-pointer text-left w-full"
        >
          <p className="text-foreground text-sm font-medium">{p.title}</p>
          <p className="text-muted-foreground text-xs mt-0.5">{p.subtitle}</p>
        </button>
      ))}
    </div>
  );
}
