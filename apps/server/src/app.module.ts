import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { ConfigModule } from '@nestjs/config';
import { SolanaModule } from './solana/index.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true, // để có thể dùng ở mọi module mà không cần import lại
    }),
    SolanaModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
