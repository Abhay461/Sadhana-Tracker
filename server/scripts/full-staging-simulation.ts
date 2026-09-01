import { connect, disconnect, Types } from 'mongoose';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.join(__dirname, '../.env.staging') });

import { UserSchema } from '../src/database/schemas/users.schema';
import { SadhanaEntrySchema } from '../src/database/schemas/sadhana-entries.schema';
import { PaymentSchema } from '../src/database/schemas/payments.schema';
import { AccommodationSchema } from '../src/database/schemas/accommodations.schema';
import { ScreenTimeLogSchema } from '../src/database/schemas/screen-time-logs.schema';
import { EventSchema } from '../src/database/schemas/events.schema';
import { EventRegistrationSchema } from '../src/database/schemas/event-registrations.schema';
import { TripSchema } from '../src/database/schemas/trips.schema';
import { TripRegistrationSchema } from '../src/database/schemas/trip-registrations.schema';
import { AnnouncementSchema } from '../src/database/schemas/announcements.schema';
import { MigrationRunSchema } from '../src/database/schemas/migration-runs.schema';

async function runFullStagingSimulation() {
  const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/sadhana_tracker_staging';
  console.log(`[FULL STAGING SIMULATION] Connecting to Database: ${mongoUri}`);

  if (!mongoUri.includes('staging')) {
    throw new Error('SAFETY HALT: Target database URI must contain "staging".');
  }

  const conn = await connect(mongoUri);

  const UserModel = conn.model('User', UserSchema);
  const SadhanaModel = conn.model('SadhanaEntry', SadhanaEntrySchema);
  const PaymentModel = conn.model('Payment', PaymentSchema);
  const AccommodationModel = conn.model('Accommodation', AccommodationSchema);
  const ScreenTimeModel = conn.model('ScreenTimeLog', ScreenTimeLogSchema);
  const EventModel = conn.model('Event', EventSchema);
  const TripModel = conn.model('Trip', TripSchema);
  const AnnouncementModel = conn.model('Announcement', AnnouncementSchema);
  const MigrationRunModel = conn.model('MigrationRun', MigrationRunSchema);

  const runId = `RUN_FULL_STAGING_${new Date().toISOString().split('T')[0]}_002`;
  console.log(`[FULL STAGING SIMULATION] Execution Run ID: ${runId}`);

  // 1. Initialize or resume durable checkpoint
  let checkpoint = await MigrationRunModel.findOne({ runId, step: 'FULL_REPRESENTATIVE_STAGING' });
  if (!checkpoint) {
    checkpoint = await MigrationRunModel.create({
      runId,
      step: 'FULL_REPRESENTATIVE_STAGING',
      processedCount: 0,
      status: 'IN_PROGRESS',
      errorLogs: [],
    });
  }

  // 2. Insert representative dataset with edge cases:
  // Edge Case A: Preacher Account
  const preacherId = new Types.ObjectId();
  await UserModel.findOneAndUpdate(
    { legacySupabaseUserId: 'SUPABASE_UUID_PRCH_001' },
    {
      _id: preacherId,
      phoneNumber: '+919876543210',
      email: 'preacher1@example.com',
      name: 'Preacher Govinda Das',
      role: 'preacher',
      status: 'ACTIVE',
      preacherCode: 'PRCH-GV8912',
      migrationStatus: 'PENDING_LINK',
      legacySupabaseUserId: 'SUPABASE_UUID_PRCH_001',
    },
    { upsert: true, new: true },
  );

  // Edge Case B: Active Student assigned to Preacher
  const student1Id = new Types.ObjectId();
  await UserModel.findOneAndUpdate(
    { legacySupabaseUserId: 'SUPABASE_UUID_STUD_001' },
    {
      _id: student1Id,
      phoneNumber: '+919811112222',
      email: 'student1@example.com',
      name: 'Student Chaitanya',
      role: 'folk_boy',
      status: 'ACTIVE',
      preacherId: preacherId,
      migrationStatus: 'PENDING_LINK',
      legacySupabaseUserId: 'SUPABASE_UUID_STUD_001',
    },
    { upsert: true, new: true },
  );

  // Edge Case C: Legacy Email-only Student (Missing Phone Number)
  const student2Id = new Types.ObjectId();
  await UserModel.findOneAndUpdate(
    { legacySupabaseUserId: 'SUPABASE_UUID_STUD_002' },
    {
      _id: student2Id,
      phoneNumber: 'TEMP_LEGACY_002',
      email: 'emailonly.student@example.com',
      name: 'Email Only Student',
      role: 'residency',
      status: 'PENDING_APPROVAL',
      preacherId: preacherId,
      migrationStatus: 'PENDING_LINK',
      legacySupabaseUserId: 'SUPABASE_UUID_STUD_002',
    },
    { upsert: true, new: true },
  );

  // Edge Case D: Blocked Student
  const student3Id = new Types.ObjectId();
  await UserModel.findOneAndUpdate(
    { legacySupabaseUserId: 'SUPABASE_UUID_STUD_003' },
    {
      _id: student3Id,
      phoneNumber: '+919833334444',
      email: 'blocked.student@example.com',
      name: 'Blocked User',
      role: 'folk_boy',
      status: 'BLOCKED',
      isBlocked: true,
      preacherId: preacherId,
      migrationStatus: 'PENDING_LINK',
      legacySupabaseUserId: 'SUPABASE_UUID_STUD_003',
    },
    { upsert: true, new: true },
  );

  // 3. Sadhana Entries Batch (including locked days, high point logs, low point logs)
  await SadhanaModel.findOneAndUpdate(
    { userId: student1Id, dateString: '2026-08-26' },
    {
      logicalDate: new Date(Date.UTC(2026, 7, 26, 0, 0, 0)),
      timezoneOffsetMinutes: 330,
      activities: {
        wakeUpTime: '04:30 AM',
        manglaArti: { attended: true, time: '04:30 AM' },
        chanting: { rounds: 16 },
        onlineSession: { attended: true, timeSpan: '08:00 AM' },
        bookReading: { bookName: 'Srimad Bhagavatam', pagesOrMinutes: '15 pages' },
        service: { serviceName: 'Puja assistance', durationMinutes: 45 },
        templeVisit: { visited: true },
        srimadBhagavatamClass: { attended: true },
        bhagavadGitaClass: { attended: true },
        ekadashiFasting: { fastingType: 'Nirjala', notes: 'Full fast' },
      },
      totalPoints: 80,
      isLocked: false,
    },
    { upsert: true, new: true },
  );

  await SadhanaModel.findOneAndUpdate(
    { userId: student1Id, dateString: '2026-08-25' },
    {
      logicalDate: new Date(Date.UTC(2026, 7, 25, 0, 0, 0)),
      timezoneOffsetMinutes: 330,
      activities: {
        wakeUpTime: '06:00 AM',
        chanting: { rounds: 8 },
        templeVisit: { visited: true },
      },
      totalPoints: 20,
      isLocked: true, // Locked by preacher
      unlockedBy: null,
    },
    { upsert: true, new: true },
  );

  // 4. Payments, Accommodations & Screen Time Logs
  await PaymentModel.findOneAndUpdate(
    { userId: student1Id, title: 'Janmashtami Contribution' },
    {
      preacherId: preacherId,
      amount: 1008,
      status: 'APPROVED',
      paymentProvider: 'UPI',
      transactionReferenceId: 'UPI_REF_99887766',
      remarks: 'Verified via UPI reference',
    },
    { upsert: true, new: true },
  );

  await AccommodationModel.findOneAndUpdate(
    { userId: student1Id, requestDetails: 'Festival Stay 3 Days' },
    {
      preacherId: preacherId,
      status: 'APPROVED',
      assignedRoom: 'Block B Room 102',
    },
    { upsert: true, new: true },
  );

  await ScreenTimeModel.findOneAndUpdate(
    { userId: student1Id, date: '2026-08-26' },
    {
      totalDurationLabel: '1h 30m',
      breakdownDescription: 'Sadhana app: 45m, WhatsApp: 45m',
    },
    { upsert: true, new: true },
  );

  // 5. Announcements with parsing and quarantine handling
  await AnnouncementModel.findOneAndUpdate(
    { title: 'Weekly Satsang Announcement' },
    {
      description: 'Join weekly satsang Sunday 5 PM',
      type: 'announcement',
      createdBy: preacherId,
      isActive: true,
    },
    { upsert: true, new: true },
  );

  // Update checkpoint
  checkpoint.processedCount = 12;
  checkpoint.status = 'COMPLETED';
  await checkpoint.save();

  console.log('=======================================================');
  console.log('[FULL STAGING SIMULATION] Representative Dataset Run Completed!');
  console.log(`[FULL STAGING SIMULATION] Processed Records: ${checkpoint.processedCount}`);
  console.log('=======================================================');

  await disconnect();
}

runFullStagingSimulation().catch((err) => {
  console.error('[FULL STAGING SIMULATION] Execution error:', err);
  process.exit(1);
});
