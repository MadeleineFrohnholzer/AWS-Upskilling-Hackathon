import * as React from "react"
import { cn } from "@/lib/utils"

function Input({ className, type, ...props }: React.ComponentProps<"input">) {
  return (
    <input
      type={type}
      data-slot="input"
      className={cn(
        "border-input bg-transparent file:text-foreground placeholder:text-[#888888] flex h-9 w-full min-w-0 rounded-md border bg-[#111111] px-3 py-1 text-base text-white shadow-xs transition-colors outline-none file:inline-flex file:h-7 file:border-0 file:bg-transparent file:text-sm file:font-medium disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 focus-visible:ring-2 focus-visible:ring-[#a100ff] focus-visible:border-[#a100ff] md:text-sm",
        className
      )}
      {...props}
    />
  )
}

export { Input }
