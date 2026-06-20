import { supabase } from "@/lib/supabase";
import type { Device } from "@/lib/types";

export default function DeviceCard({ device }: { device: Device }) {
  const lastSeen = new Date(device.last_seen);
  const minutesAgo = Math.floor((Date.now() - lastSeen.getTime()) / 60000);
  const isOnline = minutesAgo < 5;

  const toggleSyncPause = async () => {
    const newState = !device.sync_paused;
    const { error } = await supabase
      .from("devices")
      .update({ sync_paused: newState })
      .eq("id", device.id);
    if (error) console.error("[toggleSyncPause]", error);
  };

  return (
    <div className="rounded-xl border border-gray-800 bg-gray-900 p-4">
      <div className="flex items-center gap-3">
        <span
          className={`w-3 h-3 rounded-full ${
            isOnline ? "bg-green-400" : "bg-gray-600"
          }`}
        />
        <div className="flex-1">
          <div className="font-medium">{device.name}</div>
          <div className="text-xs text-gray-500 font-mono">{device.id}</div>
        </div>
        <button
          onClick={toggleSyncPause}
          className={`px-3 py-1 rounded text-xs font-medium ${
            device.sync_paused
              ? "bg-green-900 text-green-400 hover:bg-green-800"
              : "bg-red-900 text-red-400 hover:bg-red-800"
          }`}
        >
          {device.sync_paused ? "Resume Sync" : "Pause Sync"}
        </button>
      </div>
      <div className="mt-3 grid grid-cols-2 gap-2 text-xs text-gray-400">
        <div>
          <div>Last Seen</div>
          <div className="text-gray-300">
            {minutesAgo < 60
              ? `${minutesAgo} min ago`
              : lastSeen.toLocaleString()}
          </div>
        </div>
        <div>
          <div>Last Sync</div>
          <div className="text-gray-300">
            {device.last_sync
              ? new Date(device.last_sync).toLocaleString()
              : "—"}
          </div>
        </div>
      </div>
      {device.sync_paused && (
        <div className="mt-2 px-2 py-1 bg-yellow-900 text-yellow-400 text-xs rounded text-center font-medium">
          SYNCHRONISATION EN PAUSE
        </div>
      )}
    </div>
  );
}
