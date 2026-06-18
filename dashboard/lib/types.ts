export interface Backup {
  id: string;
  created_at: string;
  file_path: string;
  file_size: number;
  source: "auto" | "manual" | "on_close";
  status: "ok" | "failed" | "pending";
  error_msg: string | null;
  device_id: string;
}

export interface SyncLog {
  id: string;
  created_at: string;
  type: "sync" | "backup" | "restore" | "ping";
  device_id: string;
  details: Record<string, unknown>;
  success: boolean;
  error_msg: string | null;
}

export interface Device {
  id: string;
  name: string;
  last_seen: string;
  last_sync: string;
}
