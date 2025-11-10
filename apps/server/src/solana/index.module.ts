import { Module } from '@nestjs/common';
import { SolanaController } from './index.controller';
import { SolanaService } from './index.service';

@Module({
  controllers: [SolanaController],
  providers: [SolanaService],
})
export class SolanaModule {}
