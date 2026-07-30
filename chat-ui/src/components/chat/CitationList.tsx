import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from '@/components/ui/accordion';
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip';
import type { Citation } from '@/types/chat';

interface CitationListProps {
  citations: Citation[];
}

export function CitationList({ citations }: CitationListProps) {
  return (
    <Accordion type="single" collapsible className="mt-2">
      <AccordionItem value="citations" className="border-[#333333]">
        <AccordionTrigger className="text-[#888888] text-xs hover:text-white py-1">
          {citations.length} Source{citations.length !== 1 ? 's' : ''}
        </AccordionTrigger>
        <AccordionContent>
          <ul className="space-y-1">
            {citations.map((c, i) => (
              <li key={i} className="flex items-center gap-2 text-xs">
                <TooltipProvider>
                  <Tooltip>
                    <TooltipTrigger asChild>
                      <a
                        href={c.source}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-[#A100FF] hover:text-[#8A00E0] underline truncate max-w-xs"
                      >
                        {c.source.split('/').pop() ?? c.source}
                        {c.page != null && ` · p. ${c.page}`}
                      </a>
                    </TooltipTrigger>
                    {c.excerpt && (
                      <TooltipContent className="max-w-xs bg-[#1A1A1A] border-[#333333] text-white text-xs">
                        {c.excerpt}
                      </TooltipContent>
                    )}
                  </Tooltip>
                </TooltipProvider>
              </li>
            ))}
          </ul>
        </AccordionContent>
      </AccordionItem>
    </Accordion>
  );
}
