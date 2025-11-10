import { Test, TestingModule } from '@nestjs/testing';
import { SolanaService } from '../../src/solana/index.service';

describe('SolanaService (Integration)', () => {
  let service: SolanaService;

  beforeAll(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [SolanaService],
    }).compile();

    service = module.get<SolanaService>(SolanaService);
  });

  it('should fetch transaction count from real RPC (mainnet)', async () => {
    service.addRpc('https://api.mainnet-beta.solana.com');
    const latestSlot = await service.getLatestBlockNumber();
    const result = await service.getTxCount(latestSlot);
    expect(result).toHaveProperty('blockNumber', latestSlot);
    expect(result).toHaveProperty('transactionCount');
    expect(typeof result.transactionCount).toBe('number');
  }, 15000);

  it('should handle non-existent block gracefully', async () => {
    const blockNumber = 999999999;
    await expect(service.getTxCount(blockNumber)).rejects.toThrow();
  });
});
