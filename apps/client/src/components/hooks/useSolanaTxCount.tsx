"use client";

import { useQuery } from "@tanstack/react-query";

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000";

export function useSolanaTxCount(submittedBlock: string | null) {
  const query = useQuery({
    queryKey: ["txCount", submittedBlock],
    queryFn: async () => {
      if (!submittedBlock) return null;
      const res = await fetch(
        `${API_BASE_URL}/solana/tx-count?block=${submittedBlock}`
      );
      if (!res.ok) throw new Error("Failed to fetch data");
      return res.json();
    },
    enabled: !!submittedBlock,
  });

  return query;
}
