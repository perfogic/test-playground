"use client";

import { useState } from "react";
import { useSolanaTxCount } from "@/components/hooks/useSolanaTxCount";

export default function Home() {
  const [block, setBlock] = useState<string>("");
  const [submittedBlock, setSubmittedBlock] = useState<string | null>(null);
  const { isFetching, data, error } = useSolanaTxCount(submittedBlock);
  const handleSubmit = (e: React.FormEvent) => {
    if (Number(block) < 0 || isNaN(Number(block))) {
      alert("Please enter a valid non-negative block number.");
      return;
    }
    e.preventDefault();
    setSubmittedBlock(block);
  };

  return (
    <main className="flex flex-col items-center justify-center min-h-screen bg-gradient-to-br from-[#0b0c10] via-[#1a1a2e] to-[#0b0c10] text-white">
      <div className="w-full max-w-md bg-[#161a23]/70 backdrop-blur-md rounded-2xl p-8 shadow-2xl border border-gray-800">
        <h1 className="text-2xl font-bold mb-6 text-center text-transparent bg-clip-text bg-gradient-to-r from-[#9945FF] to-[#14F195]">
          Solana Transaction Counter
        </h1>

        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <input
            type="text"
            placeholder="Enter Solana block number"
            className="p-3 rounded-md bg-[#1f2230] border border-gray-700 text-white focus:outline-none focus:ring-2 focus:ring-[#9945FF]"
            value={block}
            onChange={(e) => setBlock(e.target.value)}
            required
          />
          <button
            type="submit"
            disabled={isFetching}
            className="bg-gradient-to-r from-[#9945FF] to-[#14F195] text-black font-semibold py-2 rounded-md hover:opacity-90 transition-all cursor-pointer"
          >
            {isFetching ? "Checking..." : "Check Block"}
          </button>
        </form>

        {error && (
          <p className="text-red-400 mt-4 text-center">
            {(error as Error).message}
          </p>
        )}

        {data && (
          <div className="mt-6 bg-[#1f2230] border border-gray-700 rounded-lg p-4 text-center">
            <p className="text-sm text-gray-400">Block Number:</p>
            <p className="text-lg font-semibold">{data.blockNumber}</p>
            <p className="mt-2 text-sm text-gray-400">Transaction Count:</p>
            <p className="text-2xl font-bold text-[#14F195]">
              {data.transactionCount}
            </p>
          </div>
        )}
      </div>
    </main>
  );
}
