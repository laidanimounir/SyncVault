export default function StatusCard({
  title,
  value,
  icon,
  highlight = false,
}: {
  title: string;
  value: string | number;
  icon: string;
  highlight?: boolean;
}) {
  return (
    <div
      className={`rounded-xl border p-4 space-y-1 ${
        highlight ? "border-red-500 bg-red-950" : "border-gray-800 bg-gray-900"
      }`}
    >
      <div className="text-2xl">{icon}</div>
      <div className="text-2xl font-bold">{value}</div>
      <div className="text-sm text-gray-400">{title}</div>
    </div>
  );
}
