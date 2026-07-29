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

const INDUSTRIES = ['Financial Services', 'Healthcare', 'Technology', 'Energy', 'Retail', 'Other'];
const DOC_TYPES = ['Contract', 'Report', 'Policy', 'Proposal', 'Invoice', 'Other'];

interface UploadSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function UploadSheet({ open, onOpenChange }: UploadSheetProps) {
  const [file, setFile] = useState<File | null>(null);
  const [progress, setProgress] = useState(0);
  const [uploading, setUploading] = useState(false);
  const [step, setStep] = useState(1);

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
          fileName: file.name,
          fileType: file.type,
          ...data,
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
        className="w-[480px] bg-[#0A0A0A] border-l border-[#333333] text-white"
      >
        <SheetHeader>
          <SheetTitle className="text-white">Upload Document</SheetTitle>
        </SheetHeader>

        {/* Step indicators */}
        <div className="flex gap-2 my-4 px-6">
          {[1, 2, 3].map((s) => (
            <div
              key={s}
              className={`h-1.5 flex-1 rounded-full ${s <= step ? 'bg-[#A100FF]' : 'bg-[#333333]'}`}
            />
          ))}
        </div>

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4 px-6">
          {step === 1 && (
            <div>
              <label
                htmlFor="file-input"
                className={`block border-2 border-dashed rounded-xl p-8 text-center cursor-pointer transition-colors ${
                  file ? 'border-[#A100FF]' : 'border-[#333333] hover:border-[#A100FF]'
                }`}
              >
                {file ? (
                  <span className="text-white text-sm">{file.name}</span>
                ) : (
                  <span className="text-[#888888] text-sm">
                    Drag &amp; drop or click to select a file
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
                    if (f) { setFile(f); setStep(2); }
                  }}
                />
              </label>
            </div>
          )}

          {step === 2 && (
            <div className="space-y-4">
              <div>
                <label className="text-[#888888] text-sm mb-1 block">Industry *</label>
                <select
                  {...register('industry')}
                  className="w-full bg-[#111111] border border-[#333333] rounded-md px-3 py-2 text-white text-sm focus:border-[#A100FF] outline-none"
                >
                  <option value="">Select industry...</option>
                  {INDUSTRIES.map((i) => <option key={i} value={i}>{i}</option>)}
                </select>
                {errors.industry && <p className="text-red-500 text-xs mt-1">{errors.industry.message}</p>}
              </div>

              <div>
                <label className="text-[#888888] text-sm mb-1 block">Document Type *</label>
                <select
                  {...register('documentType')}
                  className="w-full bg-[#111111] border border-[#333333] rounded-md px-3 py-2 text-white text-sm focus:border-[#A100FF] outline-none"
                >
                  <option value="">Select type...</option>
                  {DOC_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
                </select>
                {errors.documentType && <p className="text-red-500 text-xs mt-1">{errors.documentType.message}</p>}
              </div>

              <div>
                <label className="text-[#888888] text-sm mb-1 block">Use Case</label>
                <Input
                  {...register('useCase')}
                  placeholder="Optional..."
                  className="bg-[#111111] border-[#333333] text-white placeholder:text-[#888888]"
                />
              </div>

              <div>
                <label className="text-[#888888] text-sm mb-1 block">Client</label>
                <Input
                  {...register('client')}
                  placeholder="Optional..."
                  className="bg-[#111111] border-[#333333] text-white placeholder:text-[#888888]"
                />
              </div>
            </div>
          )}

          {step === 3 && (
            <div className="space-y-3">
              <Progress value={progress} className="bg-[#1A1A1A] [&>div]:bg-[#A100FF]" />
              <p className="text-[#888888] text-sm text-center">
                {progress < 100 ? `Uploading… ${progress}%` : 'Processing…'}
              </p>
            </div>
          )}

          {step === 2 && (
            <div className="flex gap-3 pt-2">
              <Button
                type="button"
                variant="ghost"
                className="flex-1 border border-[#333333] text-[#888888] hover:text-white"
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
