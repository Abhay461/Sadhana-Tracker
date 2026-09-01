import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { User, UserSchema } from './schemas/users.schema';
import { SadhanaEntry, SadhanaEntrySchema } from './schemas/sadhana-entries.schema';
import { UserDevice, UserDeviceSchema } from './schemas/user-devices.schema';
import { Event, EventSchema } from './schemas/events.schema';
import { EventRegistration, EventRegistrationSchema } from './schemas/event-registrations.schema';
import { Trip, TripSchema } from './schemas/trips.schema';
import { TripRegistration, TripRegistrationSchema } from './schemas/trip-registrations.schema';
import { Announcement, AnnouncementSchema } from './schemas/announcements.schema';
import { Accommodation, AccommodationSchema } from './schemas/accommodations.schema';
import { Payment, PaymentSchema } from './schemas/payments.schema';
import { Appointment, AppointmentSchema } from './schemas/appointments.schema';
import { ScreenTimeLog, ScreenTimeLogSchema } from './schemas/screen-time-logs.schema';
import { Feedback, FeedbackSchema } from './schemas/feedback.schema';
import { AuditLog, AuditLogSchema } from './schemas/audit-logs.schema';
import { MigrationRun, MigrationRunSchema } from './schemas/migration-runs.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: User.name, schema: UserSchema },
      { name: SadhanaEntry.name, schema: SadhanaEntrySchema },
      { name: UserDevice.name, schema: UserDeviceSchema },
      { name: Event.name, schema: EventSchema },
      { name: EventRegistration.name, schema: EventRegistrationSchema },
      { name: Trip.name, schema: TripSchema },
      { name: TripRegistration.name, schema: TripRegistrationSchema },
      { name: Announcement.name, schema: AnnouncementSchema },
      { name: Accommodation.name, schema: AccommodationSchema },
      { name: Payment.name, schema: PaymentSchema },
      { name: Appointment.name, schema: AppointmentSchema },
      { name: ScreenTimeLog.name, schema: ScreenTimeLogSchema },
      { name: Feedback.name, schema: FeedbackSchema },
      { name: AuditLog.name, schema: AuditLogSchema },
      { name: MigrationRun.name, schema: MigrationRunSchema },
    ]),
  ],
  exports: [MongooseModule],
})
export class DatabaseModule {}
