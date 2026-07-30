import * as React from "react"
import { cn } from "@/lib/utils"

function Textarea({ className, ...props }: React.ComponentProps<"textarea">) {
  return (
    <textarea
      data-slot="textarea"
      className={cn(
        "border-[#333333] placeholder:text-[#888888] flex min-h-16 w-full rounded-md border bg-[#111111] px-3 py-2 text-base text-white shadow-xs transition-colors outline-none focus-visible:ring-2 focus-visible:ring-[#a100ff] focus-visible:border-[#a100ff] disabled:cursor-not-allowed disabled:opacity-50 md:text-sm",
        className
      )}
      {...props}
    />
  )
}

export { Textarea }
