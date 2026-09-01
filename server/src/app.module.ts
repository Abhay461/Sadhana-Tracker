import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { MongooseModule } from '@nestjs/mongoose';
import { ThrottlerModule } from '@nestjs/throttler';
import configuration from './config/configuration';
import { validateEnvironment } from './config/validation.schema';
import { HealthModule } from './health/health.module';
import { DatabaseModule } from './database/database.module';
import { FirebaseModule } from './firebase/firebase.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { SadhanaModule } from './sadhana/sadhana.module';
import { AdminModule } from './admin/admin.module';
import { PreachersModule } from './preachers/preachers.module';
import { NotificationsModule } from './notifications/notifications.module';
import { AccommodationsModule } from './accommodations/accommodations.module';
import { PaymentsModule } from './payments/payments.module';
import { EventsModule } from './events/events.module';
import { TripsModule } from './trips/trips.module';
import { AnnouncementsModule } from './announcements/announcements.module';
import { ScreenTimeModule } from './screen-time/screen-time.module';
import { MediaModule } from './media/media.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
      validate: validateEnvironment,
    }),
    MongooseModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        uri: configService.get<string>('mongodb.uri'),
        autoIndex: true,
        serverSelectionTimeoutMS: 5000,
        connectTimeoutMS: 10000,
        retryAttempts: 5,
        retryDelay: 1000,
      }),
    }),
    ThrottlerModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => [
        {
          ttl: configService.get<number>('throttler.ttl'),
          limit: configService.get<number>('throttler.limit'),
        },
      ],
    }),
    FirebaseModule,
    DatabaseModule,
    HealthModule,
    AuthModule,
    UsersModule,
    SadhanaModule,
    AdminModule,
    PreachersModule,
    NotificationsModule,
    AccommodationsModule,
    PaymentsModule,
    EventsModule,
    TripsModule,
    AnnouncementsModule,
    ScreenTimeModule,
    MediaModule,
  ],
})
export class AppModule {}
