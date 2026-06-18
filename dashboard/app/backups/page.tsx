import { supabase } from "@/lib/supabase";
import type { Backup } from "@/lib/types";

export default async function BackupsPage() {
  const { data: backups } = await supabase
    .from("backups")
    .select("*")
    .order("created_at", { ascending: false });

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Backups</h1>
      <div className="rounded-xl border border-gray-800 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-900 text-gray-400">
            <tr>
              <th className="px-4 py-3 text-right">Date</th>
              <th className="px-4 py-3 text-right">Size</th>
              <th className="px-4 py-3 text-right">Source</th>
              <th className="px-4 py-3 text-right">Device</th>
              <th className="px-4 py-3 text-right">Status</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-800">
            {(backups as Backup[])?.map((b: Backup) => (
              <tr
                key={b.id}
                className="bg-gray-950 hover:bg-gray-900 transition"
              >
                <td className="px-4 py-3">
                  {new Date(b.created_at).toLocaleString()}
                </td>
                <td className="px-4 py-3 text-gray-400">
                  {((b.file_size ?? 0) / 1024 / 1024).toFixed(2)} MB
                </td>
                <td className="px-4 py-3">
                  <span className="px-2 py-1 rounded text-xs bg-gray-800 text-gray-300">
                    {b.source}
                  </span>
                </td>
                <td className="px-4 py-3 text-gray-400 font-mono text-xs">
                  {b.device_id}
                </td>
                <td className="px-4 py-3">
                  {b.status === "ok" ? (
                    <span className="text-green-400">OK</span>
                  ) : (
                    <span className="text-red-400">FAILED</span>
                  )}
                </td>
              </tr>
            ))}
            {(!backups || backups.length === 0) && (
              <tr>
                <td colSpan={5} className="text-gray-600 text-sm text-center py-4">
                  No backups yet
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
