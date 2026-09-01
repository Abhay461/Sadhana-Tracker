import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { InjectConnection } from '@nestjs/mongoose';
import { Connection } from 'mongoose';

@ApiTags('Health Check')
@Controller('health')
export class HealthController {
  constructor(@InjectConnection() private readonly connection: Connection) {}

  @Get()
  @ApiOperation({ summary: 'Liveness check endpoint' })
  checkLiveness() {
    return {
      status: 'UP',
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
    };
  }

  @Get('db')
  @ApiOperation({ summary: 'Readiness check for Database connection' })
  checkDbReadiness() {
    const isDbConnected = this.connection.readyState === 1;
    return {
      status: isDbConnected ? 'UP' : 'DOWN',
      database: 'MongoDB',
      readyState: this.connection.readyState,
      timestamp: new Date().toISOString(),
    };
  }
}
