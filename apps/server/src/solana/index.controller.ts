import { Controller, Get, Query, BadRequestException } from '@nestjs/common';
import { SolanaService } from './index.service';

@Controller('solana')
export class SolanaController {
  constructor(private readonly solanaService: SolanaService) {}

  @Get('tx-count')
  async getTxCount(@Query('block') block: string) {
    const blockNumber = Number(block);
    if (!block || isNaN(blockNumber)) {
      throw new BadRequestException('Invalid block number');
    }
    try {
      const result = await this.solanaService.getTxCount(blockNumber);
      return result;
    } catch (err) {
      return {
        error: 'Failed to fetch transaction count',
        details: err.message,
      };
    }
  }
}
