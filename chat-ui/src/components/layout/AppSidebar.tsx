'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { PlusIcon, SearchIcon, UploadIcon, MenuIcon } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { AccentureMark } from '@/components/brand/AccentureMark';
import { ChatHistoryList } from './ChatHistoryList';
import { UserIdentity } from './UserIdentity';
import { UploadSheet } from '@/components/upload/UploadSheet';
import { Sheet, SheetContent } from '@/components/ui/sheet';
import {
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from '@/components/ui/command';

function SidebarContent({
  onNewChat,
  onSearch,
  onUpload,
}: {
  onNewChat: () => void;
  onSearch: () => void;
  onUpload: () => void;
}) {
  return (
    <div className="flex flex-col h-full bg-background">
      {/* Header */}
      <div className="flex items-center gap-2 p-4 border-b border-border">
        <AccentureMark size={24} />
        <span className="text-foreground font-semibold text-sm tracking-tight">accenture</span>
      </div>

      {/* Nav */}
      <nav className="flex flex-col gap-1 p-2 mt-2">
        <Button
          variant="ghost"
          className="w-full justify-start text-muted-foreground hover:text-foreground hover:bg-muted"
          onClick={onNewChat}
        >
          <PlusIcon className="mr-2 h-4 w-4" />
          New Chat
        </Button>
        <Button
          variant="ghost"
          className="w-full justify-start text-muted-foreground hover:text-foreground hover:bg-muted"
          onClick={onSearch}
        >
          <SearchIcon className="mr-2 h-4 w-4" />
          Search
        </Button>
        <Button
          variant="ghost"
          className="w-full justify-start text-muted-foreground hover:text-foreground hover:bg-muted"
          onClick={onUpload}
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
      <div className="mt-auto border-t border-border p-3">
        <UserIdentity />
      </div>
    </div>
  );
}

export function AppSidebar() {
  const router = useRouter();
  const [uploadOpen, setUploadOpen] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  const handleNewChat = () => { router.push('/'); setMobileOpen(false); };
  const handleSearch = () => { setSearchOpen(true); setMobileOpen(false); };
  const handleUpload = () => { setUploadOpen(true); setMobileOpen(false); };

  return (
    <>
      {/* Mobile hamburger — visible only on small screens */}
      <Button
        variant="ghost"
        size="icon"
        className="md:hidden fixed top-2.5 left-3 z-20 text-muted-foreground hover:text-foreground"
        onClick={() => setMobileOpen(true)}
        aria-label="Open menu"
      >
        <MenuIcon className="h-5 w-5" />
      </Button>

      {/* Desktop sidebar */}
      <aside className="hidden md:flex md:flex-col w-64 bg-background border-r border-border h-screen fixed left-0 top-0 z-10">
        <SidebarContent
          onNewChat={handleNewChat}
          onSearch={handleSearch}
          onUpload={handleUpload}
        />
      </aside>

      {/* Mobile sidebar Sheet */}
      <Sheet open={mobileOpen} onOpenChange={setMobileOpen}>
        <SheetContent side="left" className="w-64 p-0 bg-background border-r border-border">
          <SidebarContent
            onNewChat={handleNewChat}
            onSearch={handleSearch}
            onUpload={handleUpload}
          />
        </SheetContent>
      </Sheet>

      <UploadSheet open={uploadOpen} onOpenChange={setUploadOpen} />

      <CommandDialog open={searchOpen} onOpenChange={setSearchOpen}>
        <CommandInput placeholder="Search conversations…" />
        <CommandList>
          <CommandEmpty>No results found.</CommandEmpty>
          <CommandGroup heading="Recent Chats">
            <CommandItem>No recent chats</CommandItem>
          </CommandGroup>
        </CommandList>
      </CommandDialog>
    </>
  );
}
