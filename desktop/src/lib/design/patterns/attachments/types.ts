export interface AttachedFile {
  id: string;
  name: string;
  size: number;
  mimeType: string;
  /** data URL for images, null for other file types */
  preview: string | null;
  file: File;
}
