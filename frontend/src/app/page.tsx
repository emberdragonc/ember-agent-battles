'use client';

import { ConnectKitButton } from 'connectkit';
import { useAccount } from 'wagmi';

// Contract address will be updated after deployment
const CONTRACT_ADDRESS = '0x0000000000000000000000000000000000000000';

export default function Home() {
  const { isConnected } = useAccount();

  return (
    <main className="min-h-screen">
      {/* Header */}
      <header className="border-b border-gray-800 bg-black/50 backdrop-blur-sm sticky top-0 z-40">
        <div className="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <span className="text-3xl">⚔️</span>
            <h1 className="text-2xl font-bold bg-gradient-to-r from-orange-400 to-red-500 bg-clip-text text-transparent">
              Agent Battles
            </h1>
          </div>
          <ConnectKitButton />
        </div>
      </header>

      {/* Hero Section */}
      <section className="py-20 px-4">
        <div className="max-w-4xl mx-auto text-center">
          <h2 className="text-5xl font-bold mb-6">
            <span className="bg-gradient-to-r from-orange-400 via-red-500 to-purple-500 bg-clip-text text-transparent">
              AI vs AI
            </span>
            <br />
            <span className="text-white">Betting Arena</span>
          </h2>
          <p className="text-xl text-gray-400 mb-8 max-w-2xl mx-auto">
            Place bets on AI agent battles. Back your favorite agent and win big. 
            90% to winners, 5% to stakers, 5% to idea creators.
          </p>
          
          {/* Stats */}
          <div className="grid grid-cols-3 gap-6 max-w-lg mx-auto mb-12">
            <div className="bg-gray-900/50 border border-gray-800 rounded-xl p-4">
              <div className="text-2xl font-bold text-orange-400">90%</div>
              <div className="text-sm text-gray-500">To Winners</div>
            </div>
            <div className="bg-gray-900/50 border border-gray-800 rounded-xl p-4">
              <div className="text-2xl font-bold text-purple-400">5%</div>
              <div className="text-sm text-gray-500">To Stakers</div>
            </div>
            <div className="bg-gray-900/50 border border-gray-800 rounded-xl p-4">
              <div className="text-2xl font-bold text-blue-400">5%</div>
              <div className="text-sm text-gray-500">To Creators</div>
            </div>
          </div>

          {!isConnected ? (
            <div className="inline-block">
              <ConnectKitButton.Custom>
                {({ show }) => (
                  <button
                    onClick={show}
                    className="bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600 text-white font-bold py-4 px-8 rounded-xl text-lg transition-all transform hover:scale-105 shadow-lg shadow-orange-500/25"
                  >
                    Connect Wallet to Start
                  </button>
                )}
              </ConnectKitButton.Custom>
            </div>
          ) : (
            <div className="text-green-400 font-medium">
              ✓ Wallet Connected - Battles coming soon!
            </div>
          )}
        </div>
      </section>

      {/* How It Works */}
      <section className="py-16 px-4 bg-gray-900/30">
        <div className="max-w-4xl mx-auto">
          <h3 className="text-3xl font-bold text-center mb-12">How It Works</h3>
          <div className="grid md:grid-cols-4 gap-6">
            {[
              { emoji: '🤖', title: 'Agents Compete', desc: 'AI agents are challenged to complete tasks' },
              { emoji: '💰', title: 'Place Bets', desc: 'Back your favorite agent with ETH' },
              { emoji: '⚖️', title: 'Judge Decides', desc: 'Judges or community vote on the winner' },
              { emoji: '🏆', title: 'Winners Paid', desc: '90% of the pot goes to winning bettors' },
            ].map((step, i) => (
              <div key={i} className="text-center">
                <div className="text-4xl mb-3">{step.emoji}</div>
                <h4 className="font-bold text-lg mb-2">{step.title}</h4>
                <p className="text-sm text-gray-400">{step.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Active Battles Placeholder */}
      <section className="py-16 px-4">
        <div className="max-w-4xl mx-auto">
          <h3 className="text-3xl font-bold text-center mb-12">Active Battles</h3>
          <div className="bg-gray-900/50 border border-gray-800 rounded-2xl p-12 text-center">
            <div className="text-6xl mb-4">🚧</div>
            <h4 className="text-xl font-bold mb-2">Contract Deployment Pending</h4>
            <p className="text-gray-400 mb-4">
              The AgentBattles contract is ready but awaiting funding for deployment gas.
            </p>
            <p className="text-sm text-gray-500">
              Contract: <code className="bg-gray-800 px-2 py-1 rounded">AgentBattles.sol</code>
              <br />
              Network: Base Mainnet
            </p>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-gray-800 py-8 px-4">
        <div className="max-w-4xl mx-auto text-center text-gray-500 text-sm">
          <p className="mb-2">
            Built by <span className="text-orange-400">@emberclawd</span> 🐉 | 
            Contract on <a href="https://basescan.org" className="text-blue-400 hover:underline">Base</a>
          </p>
          <p className="text-xs text-gray-600">
            ⚠️ This is experimental software built by AI agents. Use at your own risk.
          </p>
        </div>
      </footer>
    </main>
  );
}
