"use client"

import { Toaster as Sonner, type ToasterProps } from "sonner"

function Toaster({ ...props }: ToasterProps) {
  return (
    <Sonner
      theme="dark"
      className="toaster group"
      style={
        {
          "--normal-bg": "#111111",
          "--normal-text": "#ffffff",
          "--normal-border": "#333333",
        } as React.CSSProperties
      }
      {...props}
    />
  )
}

export { Toaster }
