'use client';

import { supabase } from "@/lib/supabase";
import StatusCard from "@/components/StatusCard";
import SecurityBadge from "@/components/SecurityBadge";
import DeviceCard from "@/components/DeviceCard";
import SyncStatusCard from "@/components/SyncStatusCard";
import type { Backup, Device } from "@/lib/types";

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

export default async function HomePage() {
  const { data: backups, error: backupsError } = await supabase
    .from("backups")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(1);
  if (backupsError) console.error("[backups]", backupsError);

  const { count: totalBackups, error: totalError } = await supabase
    .from("backups")
    .select("*", { count: "exact", head: true });
  if (totalError) console.error("[totalBackups]", totalError);

  const { count: failedOps, error: failedError } = await supabase
    .from("sync_logs")
    .select("*", { count: "exact", head: true })
    .eq("success", false);
  if (failedError) console.error("[failedOps]", failedError);

  const { data: devices, error: devicesError } = await supabase
    .from("devices")
    .select("*")
    .order("last_seen", { ascending: false });
  if (devicesError) console.error("[devices]", devicesError);

  const lastBackup = (backups?.[0] ?? null) as Backup | null;
  const lastBackupDate = lastBackup ? new Date(lastBackup.created_at) : null;

  const daysSinceBackup = lastBackupDate
    ? Math.floor((Date.now() - lastBackupDate.getTime()) / 86400000)
    : 999;

  const securityLevel =
    daysSinceBackup < 2 ? "green" : daysSinceBackup < 7 ? "yellow" : "red";

  const totalSize = backups?.reduce(
    (sum: number, b: Backup) => sum + (b.file_size ?? 0),
    0
  ) ?? 0;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Dashboard</h1>
        <SecurityBadge level={securityLevel} daysSince={daysSinceBackup} />
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <StatusCard
          title="Total Backups"
          value={totalBackups ?? 0}
          icon=""
        />
        <StatusCard
          title="Last Successful Backup"
          value={
            lastBackupDate
              ? `${daysSinceBackup} day${daysSinceBackup !== 1 ? "s" : ""} ago`
              : "None"
          }
          icon=""
        />
        <StatusCard
          title="Failed Operations"
          value={failedOps ?? 0}
          icon=""
          highlight={(failedOps ?? 0) > 0}
        />
        <StatusCard title="Storage Used" value={formatBytes(totalSize)} icon="" />
      </div>

      <div>
        <h2 className="text-lg font-semibold mb-3">Connected Devices</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {(devices as Device[])?.map((device: Device) => (
            <DeviceCard key={device.id} device={device} />
          ))}
          {(!devices || devices.length === 0) && (
            <div className="text-gray-600 text-sm col-span-2 py-4">
              No devices registered yet
            </div>
          )}
        </div>
      </div>

      <SyncStatusCard />
    </div>
  );
}
