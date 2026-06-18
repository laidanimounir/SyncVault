import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "SyncVault Dashboard",
  description: "Smart offline-first sync and backup system",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ar" dir="rtl">
      <body className="bg-gray-950 text-gray-100 min-h-screen">
        <nav className="border-b border-gray-800 px-6 py-4 flex items-center gap-6">
          <span className="font-bold text-lg">SyncVault</span>
          <a href="/" className="text-gray-400 hover:text-white text-sm">
            Home
          </a>
          <a
            href="/backups"
            className="text-gray-400 hover:text-white text-sm"
          >
            Backups
          </a>
          <a href="/logs" className="text-gray-400 hover:text-white text-sm">
            Logs
          </a>
        </nav>
        <main className="p-6">{children}</main>
      </body>
    </html>
  );
}
