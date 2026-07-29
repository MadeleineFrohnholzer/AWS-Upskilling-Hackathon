'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { PlusIcon, SearchIcon, UploadIcon } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { AccentureMark } from '@/components/brand/AccentureMark';
import { ChatHistoryList } from './ChatHistoryList';
import { UserIdentity } from './UserIdentity';
import { UploadSheet } from '@/components/upload/UploadSheet';
import {
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from '@/components/ui/command';

export function AppSidebar() {
  const router = useRouter();
  const [uploadOpen, setUploadOpen] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);

  return (
    <>
      <aside className="w-64 bg-black border-r border-[#333333] flex flex-col h-screen fixed left-0 top-0 z-10">
        {/* Header */}
        <div className="flex items-center gap-2 p-4 border-b border-[#333333]">
          <AccentureMark size={24} />
          <span className="text-white font-semibold text-sm tracking-tight">accenture</span>
        </div>

        {/* Nav */}
        <nav className="flex flex-col gap-1 p-2 mt-2">
          <Button
            variant="ghost"
            className="w-full justify-start text-[#888888] hover:text-white hover:bg-[#1A1A1A]"
            onClick={() => router.push('/')}
          >
            <PlusIcon className="mr-2 h-4 w-4" />
            New Chat
          </Button>
          <Button
            variant="ghost"
            className="w-full justify-start text-[#888888] hover:text-white hover:bg-[#1A1A1A]"
            onClick={() => setSearchOpen(true)}
          >
            <SearchIcon className="mr-2 h-4 w-4" />
            Search
          </Button>
          <Button
            variant="ghost"
            className="w-full justify-start text-[#888888] hover:text-white hover:bg-[#1A1A1A]"
            onClick={() => setUploadOpen(true)}
          >
            <UploadIcon className="mr-2 h-4 w-4" />
            Upload Document
          </Button>
        </nav>

        {/* Chat history */}
        <div className="flex-1 overflow-hidden">
          <ChatHistoryList />
        </div>

        {/* User identity */}
        <div className="mt-auto border-t border-[#333333] p-3">
          <UserIdentity />
        </div>
      </aside>

      <UploadSheet open={uploadOpen} onOpenChange={setUploadOpen} />

      <CommandDialog open={searchOpen} onOpenChange={setSearchOpen}>
        <CommandInput placeholder="Search conversations..." className="text-white placeholder:text-[#888888]" />
        <CommandList>
          <CommandEmpty className="text-[#888888]">No results found.</CommandEmpty>
          <CommandGroup heading="Recent Chats">
            <CommandItem>No recent chats</CommandItem>
          </CommandGroup>
        </CommandList>
      </CommandDialog>
    </>
  );
}
