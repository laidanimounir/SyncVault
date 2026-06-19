import { supabase } from "@/lib/supabase";

export async function getClientLogs() {
  const { data, error } = await supabase
    .from("sync_logs")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(5);
  if (error) console.error("[getClientLogs]", error);
  return data ?? [];
}
