'use client';

import { supabase } from "@/lib/supabase";
import type { SyncLog } from "@/lib/types";

export default async function LogsPage() {
  const { data: logs, error } = await supabase
    .from("sync_logs")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(100);
  if (error) console.error("[logs]", error);

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Activity Log</h1>
      <div className="rounded-xl border border-gray-800 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-900 text-gray-400">
            <tr>
              <th className="px-4 py-3 text-right">Time</th>
              <th className="px-4 py-3 text-right">Type</th>
              <th className="px-4 py-3 text-right">Device</th>
              <th className="px-4 py-3 text-right">Details</th>
              <th className="px-4 py-3 text-right">Result</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-800">
            {(logs as SyncLog[])?.map((log: SyncLog) => (
              <tr
                key={log.id}
                className="bg-gray-950 hover:bg-gray-900 transition"
              >
                <td className="px-4 py-3 text-gray-400 text-xs">
                  {new Date(log.created_at).toLocaleString()}
                </td>
                <td className="px-4 py-3">
                  <span className="px-2 py-1 rounded text-xs bg-gray-800 text-gray-300">
                    {log.type}
                  </span>
                </td>
                <td className="px-4 py-3 font-mono text-xs text-gray-400">
                  {log.device_id ?? "—"}
                </td>
                <td className="px-4 py-3 text-gray-300 text-xs">
                  {JSON.stringify(log.details ?? {})}
                </td>
                <td className="px-4 py-3">
                  {log.success ? (
                    <span className="text-green-400">OK</span>
                  ) : (
                    <span className="text-red-400">FAILED</span>
                  )}
                </td>
              </tr>
            ))}
            {(!logs || logs.length === 0) && (
              <tr>
                <td colSpan={5} className="text-gray-600 text-sm text-center py-4">
                  No activity logged yet
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
