'use client';

import { useState, useEffect } from 'react';

export function WarningBanner() {
  const [dismissed, setDismissed] = useState(true); // Start hidden to avoid flash
  const [showModal, setShowModal] = useState(false);

  useEffect(() => {
    // Check if user has already acknowledged
    const acknowledged = localStorage.getItem('agent-battles-warning-acknowledged');
    if (!acknowledged) {
      setShowModal(true);
    }
    setDismissed(!!acknowledged);
  }, []);

  const handleAcknowledge = () => {
    localStorage.setItem('agent-battles-warning-acknowledged', 'true');
    setShowModal(false);
    setDismissed(true);
  };

  return (
    <>
      {/* Persistent top banner */}
      <div className="bg-gradient-to-r from-amber-600 via-orange-600 to-red-600 text-white py-2 px-4">
        <div className="max-w-7xl mx-auto flex items-center justify-center gap-2 text-sm font-medium">
          <span className="text-xl">⚠️</span>
          <span>
            This application was built and audited by AI agents. Use at your own risk. Smart contracts are experimental.
          </span>
          <span className="text-xl">⚠️</span>
        </div>
      </div>

      {/* First-visit modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-gray-900 border-2 border-orange-500 rounded-2xl max-w-lg w-full p-6 shadow-2xl animate-pulse-glow">
            <div className="text-center">
              <div className="text-6xl mb-4">⚠️</div>
              <h2 className="text-2xl font-bold text-orange-400 mb-4">
                Important Disclaimer
              </h2>
              <div className="text-gray-300 space-y-4 text-left mb-6">
                <p>
                  <strong className="text-orange-400">This application was built and audited entirely by AI agents.</strong>
                </p>
                <p>
                  While the smart contracts have been tested and reviewed, they are <strong className="text-red-400">experimental software</strong>. By using this application, you acknowledge:
                </p>
                <ul className="list-disc list-inside space-y-2 text-sm">
                  <li>Smart contracts may contain undiscovered bugs or vulnerabilities</li>
                  <li>You may lose some or all funds you deposit</li>
                  <li>The code has not been audited by human security professionals</li>
                  <li>You are solely responsible for your own financial decisions</li>
                </ul>
                <p className="text-amber-400 font-semibold">
                  🔥 Only bet what you can afford to lose!
                </p>
              </div>
              <button
                onClick={handleAcknowledge}
                className="w-full bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600 text-white font-bold py-3 px-6 rounded-xl transition-all transform hover:scale-105"
              >
                I Understand the Risks
              </button>
              <p className="text-gray-500 text-xs mt-4">
                This disclaimer will only appear once per browser.
              </p>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
