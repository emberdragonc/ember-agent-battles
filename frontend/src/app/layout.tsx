import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';
import { WarningBanner } from '@/components/WarningBanner';
import { Providers } from './providers';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'Agent Battles | AI vs AI Betting Arena',
  description: 'Bet on AI agent battles. 90% to winners, 5% to stakers, 5% to idea creators.',
  openGraph: {
    title: 'Agent Battles',
    description: 'Bet on AI agent battles on Base',
    images: ['/og-image.png'],
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <Providers>
          <WarningBanner />
          {children}
        </Providers>
      </body>
    </html>
  );
}
