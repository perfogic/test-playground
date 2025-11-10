import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { SolanaModule } from '../../src/solana/index.module';
import { SolanaService } from '../../src/solana/index.service';

// e2e: API will be mocked
describe('SolanaController (e2e)', () => {
  let app: INestApplication;
  let solanaService: SolanaService;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [SolanaModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();

    solanaService = moduleFixture.get<SolanaService>(SolanaService);
  });

  afterAll(async () => {
    await app.close();
  });

  describe('GET /solana/tx-count', () => {
    it('should return transaction count for valid block', async () => {
      jest.spyOn(solanaService, 'getTxCount').mockResolvedValue({
        blockNumber: 123456789,
        transactionCount: 42,
      });

      const res = await request(app.getHttpServer())
        .get('/solana/tx-count?block=123456789')
        .expect(200);

      expect(res.body).toHaveProperty('blockNumber', 123456789);
      expect(res.body).toHaveProperty('transactionCount', 42);
    });

    it('should return 400 if block number is invalid', async () => {
      const res = await request(app.getHttpServer())
        .get('/solana/tx-count?block=invalid')
        .expect(400);
      expect(res.body.message).toContain('Invalid block number');
    });

    it('should handle service errors gracefully', async () => {
      jest
        .spyOn(solanaService, 'getTxCount')
        .mockRejectedValue(new Error('Both RPC calls failed'));

      const res = await request(app.getHttpServer())
        .get('/solana/tx-count?block=999')
        .expect(200); // controller catch error and return json

      expect(res.body).toHaveProperty(
        'error',
        'Failed to fetch transaction count',
      );
      expect(res.body.details).toBe('Both RPC calls failed');
    });
  });
});
