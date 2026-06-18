export default function SecurityBadge({
  level,
  daysSince,
}: {
  level: "green" | "yellow" | "red";
  daysSince: number;
}) {
  const config = {
    green: {
      bg: "bg-green-900",
      text: "text-green-400",
      dot: "bg-green-400",
      label: "Secure",
    },
    yellow: {
      bg: "bg-yellow-900",
      text: "text-yellow-400",
      dot: "bg-yellow-400",
      label: "Warning",
    },
    red: {
      bg: "bg-red-900",
      text: "text-red-400",
      dot: "bg-red-400",
      label: "Danger",
    },
  }[level];

  return (
    <div
      className={`flex items-center gap-2 px-4 py-2 rounded-full ${config.bg}`}
    >
      <span className={`w-2 h-2 rounded-full ${config.dot} animate-pulse`} />
      <span className={`text-sm font-medium ${config.text}`}>
        {config.label} — last backup {daysSince} day
        {daysSince !== 1 ? "s" : ""} ago
      </span>
    </div>
  );
}
