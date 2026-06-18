import { supabase } from "@/lib/supabase";

export async function getClientLogs() {
  const { data } = await supabase
    .from("sync_logs")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(5);
  return data ?? [];
}
