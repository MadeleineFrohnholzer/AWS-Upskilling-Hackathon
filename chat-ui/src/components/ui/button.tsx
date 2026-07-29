import * as React from "react"
import { Slot } from "@radix-ui/react-slot"
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "@/lib/utils"

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium transition-all disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4 shrink-0 [&_svg]:shrink-0 outline-none focus-visible:ring-2 focus-visible:ring-[#a100ff] focus-visible:ring-offset-1 cursor-pointer",
  {
    variants: {
      variant: {
        default:
          "bg-[#a100ff] text-white shadow-xs hover:bg-[#8a00e0]",
        destructive:
          "bg-[#ef4444] text-white shadow-xs hover:bg-[#dc2626]",
        outline:
          "border border-[#333333] bg-transparent shadow-xs hover:bg-[#1a1a1a] hover:text-white",
        secondary:
          "bg-[#1a1a1a] text-white shadow-xs hover:bg-[#222222]",
        ghost:
          "hover:bg-[#1a1a1a] hover:text-white",
        link:
          "text-[#a100ff] underline-offset-4 hover:underline",
      },
      size: {
        default: "h-9 px-4 py-2 has-[>svg]:px-3",
        sm: "h-8 rounded-md px-3 has-[>svg]:px-2.5",
        lg: "h-10 rounded-md px-6 has-[>svg]:px-4",
        icon: "size-9",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)

function Button({
  className,
  variant,
  size,
  asChild = false,
  ...props
}: React.ComponentProps<"button"> &
  VariantProps<typeof buttonVariants> & {
    asChild?: boolean
  }) {
  const Comp = asChild ? Slot : "button"
  return (
    <Comp
      data-slot="button"
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  )
}

export { Button, buttonVariants }
