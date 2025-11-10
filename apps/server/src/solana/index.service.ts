import { Injectable, Logger } from '@nestjs/common';
import { Connection } from '@solana/web3.js';
import { LRUCache } from 'lru-cache';
import { TxCountResult } from './index.types';

@Injectable()
export class SolanaService {
  private readonly logger = new Logger(SolanaService.name);
  private cache: LRUCache<number, TxCountResult>;
  private rpcs: string[] = [];

  constructor() {
    if (process.env.SOLANA_RPC) {
      this.rpcs.push(process.env.SOLANA_RPC!);
    }
    if (process.env.FALLBACK_RPC_URL) {
      this.rpcs.push(process.env.FALLBACK_RPC_URL!);
    }
    this.cache = new LRUCache<number, TxCountResult>({
      max: 500,
      ttl: 30 * 1000, // 30s
      updateAgeOnGet: true,
    });
    this.logger.log(`SolanaService initialized with cache(max=500, ttl=30s)`);
  }

  async getTxCount(blockNumber: number): Promise<TxCountResult> {
    const cached = this.cache.get(blockNumber);
    if (cached) {
      this.logger.debug(`🟢 Cache hit for block ${blockNumber}`);
      return cached;
    }

    for (const rpcUrl of this.rpcs) {
      try {
        const connection = new Connection(rpcUrl, 'confirmed');
        const blockData = await connection.getBlock(blockNumber, {
          maxSupportedTransactionVersion: 0,
        });
        const txCount = blockData?.transactions?.length ?? 0;
        const result = { blockNumber, transactionCount: txCount };
        this.cache.set(blockNumber, result);
        this.logger.debug(`🟡 Cache miss → stored block ${blockNumber}`);
        return result;
      } catch (err) {}
    }

    throw new Error('All RPCs failed to fetch block data');
  }

  async getLatestBlockNumber(): Promise<number> {
    for (const rpcUrl of this.rpcs) {
      try {
        const connection = new Connection(rpcUrl, 'confirmed');
        const slot = await connection.getSlot();
        return slot;
      } catch (err) {
        this.logger.warn(`RPC ${rpcUrl} failed to get latest block number`);
      }
    }
    throw new Error('All RPCs failed to fetch latest block number');
  }

  addRpc(rpcUrl: string) {
    this.rpcs.push(rpcUrl);
  }
}
