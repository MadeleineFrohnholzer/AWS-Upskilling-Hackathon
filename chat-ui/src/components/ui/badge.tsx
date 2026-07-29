import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "@/lib/utils"

const badgeVariants = cva(
  "inline-flex items-center justify-center rounded-md border px-2 py-0.5 text-xs font-medium w-fit whitespace-nowrap shrink-0 gap-1 [&>svg]:size-3 overflow-hidden transition-colors",
  {
    variants: {
      variant: {
        default:
          "border-transparent bg-[#a100ff] text-white [a&]:hover:bg-[#8a00e0]",
        secondary:
          "border-transparent bg-[#1a1a1a] text-white [a&]:hover:bg-[#222222]",
        destructive:
          "border-transparent bg-[#ef4444] text-white [a&]:hover:bg-[#dc2626]",
        outline:
          "text-white [a&]:hover:bg-[#1a1a1a]",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  }
)

function Badge({
  className,
  variant,
  asChild = false,
  ...props
}: React.ComponentProps<"span"> &
  VariantProps<typeof badgeVariants> & { asChild?: boolean }) {
  return (
    <span
      data-slot="badge"
      className={cn(badgeVariants({ variant }), className)}
      {...props}
    />
  )
}

export { Badge, badgeVariants }
