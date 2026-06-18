import { supabase } from "@/lib/supabase";
import type { SyncLog } from "@/lib/types";
import { getClientLogs } from "./get-logs";

export default async function SyncStatusCard() {
  const logs = await getClientLogs();

  return (
    <div className="rounded-xl border border-gray-800 bg-gray-900 p-4">
      <h2 className="font-semibold mb-3 flex items-center gap-2">
        <span className="w-2 h-2 bg-green-400 rounded-full animate-pulse" />
        Recent Activity
      </h2>
      <div className="space-y-2">
        {logs.map((log: SyncLog) => (
          <div
            key={log.id}
            className="flex items-center justify-between text-sm py-2 border-b border-gray-800 last:border-0"
          >
            <span className="text-gray-400 text-xs">
              {new Date(log.created_at).toLocaleTimeString()}
            </span>
            <span className="text-gray-300">{log.type}</span>
            <span>
              {log.success ? (
                <span className="text-green-400">OK</span>
              ) : (
                <span className="text-red-400">FAIL</span>
              )}
            </span>
          </div>
        ))}
        {logs.length === 0 && (
          <div className="text-gray-600 text-sm text-center py-4">
            No activity yet
          </div>
        )}
      </div>
    </div>
  );
}
