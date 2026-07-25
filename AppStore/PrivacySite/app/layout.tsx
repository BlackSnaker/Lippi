import type { Metadata } from "next";
import { Geist } from "next/font/google";
import "./globals.css";

const geist = Geist({
  variable: "--font-geist",
  subsets: ["latin", "cyrillic"],
});

export const metadata: Metadata = {
  title: {
    default: "Lippi — Фокус, умные цели и забота о себе",
    template: "Lippi — %s",
  },
  description:
    "Lippi помогает держать важное в фокусе, строить умные цели, беречь энергию и управлять днём — прямо на iPhone.",
  applicationName: "Lippi",
  category: "productivity",
  keywords: [
    "Lippi",
    "продуктивность",
    "умные цели",
    "Помодоро",
    "фокус",
    "Apple Watch",
  ],
  icons: {
    icon: "/favicon.svg",
  },
  formatDetection: {
    email: false,
    address: false,
    telephone: false,
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ru">
      <body className={geist.variable}>
        {children}
        <script src="/motion.js" defer />
      </body>
    </html>
  );
}
