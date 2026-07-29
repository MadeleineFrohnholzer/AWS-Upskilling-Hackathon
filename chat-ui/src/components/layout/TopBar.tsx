import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Settings } from 'lucide-react';

export function TopBar() {
  const appName = process.env.NEXT_PUBLIC_APP_NAME ?? 'Knowledge Assistant';
  return (
    <div className="h-12 border-b border-[#333333] flex items-center justify-between px-4 bg-black">
      <Badge className="bg-[#1A1A1A] text-[#888888] border-[#333333]">
        {appName}
      </Badge>
      <div className="flex items-center gap-2">
        <Button variant="ghost" size="icon" className="text-[#888888] hover:text-white">
          <Settings className="h-4 w-4" />
        </Button>
        <Avatar className="w-7 h-7">
          <AvatarFallback className="bg-[#A100FF] text-white text-xs">
            U
          </AvatarFallback>
        </Avatar>
      </div>
    </div>
  );
}
