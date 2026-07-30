'use client';

import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { toast } from 'sonner';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Progress } from '@/components/ui/progress';

const schema = z.object({
  industry: z.string().min(1, 'Industry is required'),
  documentType: z.string().min(1, 'Document type is required'),
  useCase: z.string().optional(),
  client: z.string().optional(),
});

type FormData = z.infer<typeof schema>;

const INDUSTRIES = ['CMT', 'FSI', 'H&PS', 'PRD - Automotive', 'PRD - Consumer Goods', 'PRD - Industrial', 'PRD - Life Science', 'RES', 'Other'];
const DOC_TYPES = ['Architecture', 'Assessment / Diagnostic', 'Case Study', 'Discussion Deck', 'Executive Summary', 'Point of View / Whitepaper', 'PoC', 'Proposal', 'RFP', 'Roadmap', 'Runbook', 'Statement of Work (SOW)', 'Other'];
const USE_CASES = ['Application Modernization', 'Cloud Migration', 'Cybersecurity', 'Data & Analytics Platform', 'DB Migration', 'DevOps / Platform Engineering', 'Digital Transformation', 'Disaster Recovery / Resilience', 'ERP Implementation', 'GenAI / AI Agent', 'Infrastructure Optimization / FinOps', 'Managed Services', 'Other'];

interface UploadSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function UploadSheet({ open, onOpenChange }: UploadSheetProps) {
  const [file, setFile] = useState<File | null>(null);
  const [progress, setProgress] = useState(0);
  const [uploading, setUploading] = useState(false);
  const [step, setStep] = useState(1);
  const [isDragging, setIsDragging] = useState(false);

  const acceptFile = (f: File) => { setFile(f); setStep(2); };

  const handleDragOver = (e: React.DragEvent) => { e.preventDefault(); setIsDragging(true); };
  const handleDragLeave = (e: React.DragEvent) => { e.preventDefault(); setIsDragging(false); };
  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    const f = e.dataTransfer.files?.[0];
    if (f) acceptFile(f);
  };

  const { register, handleSubmit, formState: { errors }, reset } = useForm<FormData>({
    resolver: zodResolver(schema),
  });

  const handleClose = () => {
    onOpenChange(false);
    setFile(null);
    setProgress(0);
    setUploading(false);
    setStep(1);
    reset();
  };

  const onSubmit = async (data: FormData) => {
    if (!file) return;
    setUploading(true);
    setStep(3);

    try {
      const res = await fetch('/api/upload-url', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          filename: file.name,
          fileType: file.type,
          Industry: data.industry,
          DocumentType: data.documentType,
          ...(data.useCase && { UseCase: data.useCase }),
          ...(data.client && { Client: data.client }),
        }),
      });
      const { url } = await res.json();

      await new Promise<void>((resolve, reject) => {
        const xhr = new XMLHttpRequest();
        xhr.upload.onprogress = (e) => {
          if (e.lengthComputable) {
            setProgress(Math.round((e.loaded / e.total) * 100));
          }
        };
        xhr.onload = () => (xhr.status >= 200 && xhr.status < 300 ? resolve() : reject());
        xhr.onerror = reject;
        xhr.open('PUT', url);
        xhr.setRequestHeader('Content-Type', file.type);
        xhr.send(file);
      });

      toast.success('Document uploaded successfully');
      handleClose();
    } catch {
      toast.error('Upload failed. Please try again.');
      setUploading(false);
      setStep(2);
    }
  };

  return (
    <Sheet open={open} onOpenChange={handleClose}>
      <SheetContent
        side="right"
        className="w-full sm:w-[480px] bg-background border-l border-border text-foreground"
      >
        <SheetHeader>
          <SheetTitle className="text-foreground">Upload Document</SheetTitle>
        </SheetHeader>

        {/* Step indicators */}
        <div className="flex gap-2 my-4 px-6">
          {[1, 2, 3].map((s) => (
            <div
              key={s}
              className={`h-1.5 flex-1 rounded-full ${s <= step ? 'bg-[#A100FF]' : 'bg-border'}`}
            />
          ))}
        </div>

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4 px-6">
          {step === 1 && (
            <div>
              <label
                htmlFor="file-input"
                className={`block border-2 border-dashed rounded-xl p-8 text-center cursor-pointer transition-colors ${
                  file || isDragging ? 'border-[#A100FF] bg-[rgba(161,0,255,0.04)]' : 'border-border hover:border-[#A100FF]'
                }`}
                onDragOver={handleDragOver}
                onDragLeave={handleDragLeave}
                onDrop={handleDrop}
              >
                {file ? (
                  <span className="text-foreground text-sm">{file.name}</span>
                ) : (
                  <span className="text-muted-foreground text-sm">
                    {isDragging ? 'Drop to upload' : 'Drag & drop or click to select a file'}
                    <br />
                    <span className="text-xs">.pdf, .docx, .txt, .pptx</span>
                  </span>
                )}
                <input
                  id="file-input"
                  type="file"
                  accept=".pdf,.docx,.txt,.pptx"
                  className="hidden"
                  onChange={(e) => {
                    const f = e.target.files?.[0];
                    if (f) acceptFile(f);
                  }}
                />
              </label>
            </div>
          )}

          {step === 2 && (
            <div className="space-y-4">
              <div>
                <label className="text-muted-foreground text-sm mb-1 block">Industry *</label>
                <select
                  {...register('industry')}
                  className="w-full bg-card border border-border rounded-md px-3 py-2 text-foreground text-sm focus:border-[#A100FF] outline-none"
                >
                  <option value="">Select industry...</option>
                  {INDUSTRIES.map((i) => <option key={i} value={i}>{i}</option>)}
                </select>
                {errors.industry && <p className="text-red-500 text-xs mt-1">{errors.industry.message}</p>}
              </div>

              <div>
                <label className="text-muted-foreground text-sm mb-1 block">Document Type *</label>
                <select
                  {...register('documentType')}
                  className="w-full bg-card border border-border rounded-md px-3 py-2 text-foreground text-sm focus:border-[#A100FF] outline-none"
                >
                  <option value="">Select type...</option>
                  {DOC_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
                </select>
                {errors.documentType && <p className="text-red-500 text-xs mt-1">{errors.documentType.message}</p>}
              </div>

              <div>
                <label className="text-muted-foreground text-sm mb-1 block">Use Case</label>
                <select
                  {...register('useCase')}
                  className="w-full bg-card border border-border rounded-md px-3 py-2 text-foreground text-sm focus:border-[#A100FF] outline-none"
                >
                  <option value="">Select use case...</option>
                  {USE_CASES.map((u) => <option key={u} value={u}>{u}</option>)}
                </select>
              </div>

              <div>
                <label className="text-muted-foreground text-sm mb-1 block">Client</label>
                <Input
                  {...register('client')}
                  placeholder="Optional..."
                  className="bg-card border-border text-foreground placeholder:text-muted-foreground"
                />
              </div>
            </div>
          )}

          {step === 3 && (
            <div className="space-y-3">
              <Progress value={progress} className="bg-muted [&>div]:bg-[#A100FF]" />
              <p className="text-muted-foreground text-sm text-center">
                {progress < 100 ? `Uploading… ${progress}%` : 'Processing…'}
              </p>
            </div>
          )}

          {step === 2 && (
            <div className="flex gap-3 pt-2">
              <Button
                type="button"
                variant="ghost"
                className="flex-1 border border-border text-muted-foreground hover:text-foreground"
                onClick={() => setStep(1)}
              >
                Back
              </Button>
              <Button
                type="submit"
                className="flex-1 bg-[#A100FF] hover:bg-[#8A00E0] text-white"
                disabled={uploading}
              >
                Upload
              </Button>
            </div>
          )}
        </form>
      </SheetContent>
    </Sheet>
  );
}
