import type { Metadata } from "next";
import { Geist } from "next/font/google";
import "./globals.css";

const geist = Geist({
  variable: "--font-geist",
  subsets: ["latin", "cyrillic"],
});

export const metadata: Metadata = {
  metadataBase: new URL(
    "https://lippi-privacy.contu4575gazeta-pl.chatgpt.site",
  ),
  title: {
    default: "Lippi — Privacy Policy",
    template: "%s · Lippi",
  },
  description:
    "Lippi keeps goals, health context, voice interactions, and local intelligence private by design.",
  openGraph: {
    title: "Privacy, by design — Lippi",
    description:
      "On-device intelligence, clear permissions, and no cross-app tracking.",
    type: "website",
    images: ["/og.png"],
  },
  twitter: {
    card: "summary_large_image",
    title: "Privacy, by design — Lippi",
    description:
      "On-device intelligence, clear permissions, and no cross-app tracking.",
    images: ["/og.png"],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={geist.variable}>{children}</body>
    </html>
  );
}
