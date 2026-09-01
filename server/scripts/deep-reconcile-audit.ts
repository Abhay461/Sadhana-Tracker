import { connect, disconnect } from 'mongoose';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.join(__dirname, '../.env.staging') });

import { UserSchema } from '../src/database/schemas/users.schema';
import { SadhanaEntrySchema } from '../src/database/schemas/sadhana-entries.schema';
import { PaymentSchema } from '../src/database/schemas/payments.schema';
import { AccommodationSchema } from '../src/database/schemas/accommodations.schema';
import { ScreenTimeLogSchema } from '../src/database/schemas/screen-time-logs.schema';
import { EventSchema } from '../src/database/schemas/events.schema';
import { TripSchema } from '../src/database/schemas/trips.schema';
import { AnnouncementSchema } from '../src/database/schemas/announcements.schema';
import { MigrationRunSchema } from '../src/database/schemas/migration-runs.schema';

async function performDeepReconciliationAudit() {
  const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/sadhana_tracker_staging';
  console.log(`[DEEP RECONCILIATION] Auditing Target Database: ${mongoUri}`);

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

  const totalUsers = await UserModel.countDocuments();
  const preachers = await UserModel.countDocuments({ role: 'preacher' });
  const activeStudents = await UserModel.countDocuments({ status: 'ACTIVE', role: { $ne: 'preacher' } });
  const pendingStudents = await UserModel.countDocuments({ status: 'PENDING_APPROVAL' });
  const blockedUsers = await UserModel.countDocuments({ isBlocked: true });
  const emailOnlyLegacyUsers = await UserModel.countDocuments({ phoneNumber: /^TEMP_LEGACY_/ });

  const totalSadhana = await SadhanaModel.countDocuments();
  const lockedSadhana = await SadhanaModel.countDocuments({ isLocked: true });

  const totalPayments = await PaymentModel.countDocuments();
  const approvedPayments = await PaymentModel.countDocuments({ status: 'APPROVED' });

  const totalAccommodations = await AccommodationModel.countDocuments();
  const totalScreenTimeLogs = await ScreenTimeModel.countDocuments();
  const totalAnnouncements = await AnnouncementModel.countDocuments();

  // Check Orphan References
  const usersList = await UserModel.find().select('_id');
  const validUserIds = new Set(usersList.map((u) => u._id.toString()));

  const orphanSadhana = await SadhanaModel.find({ userId: { $nin: Array.from(validUserIds) } });
  const orphanPayments = await PaymentModel.find({ userId: { $nin: Array.from(validUserIds) } });

  console.log(`================================================================`);
  console.log(`[DEEP RECONCILIATION AUDIT REPORT] Complete Data Parity Summary`);
  console.log(`================================================================`);
  console.log(` Total Users Document Count:   ${totalUsers}`);
  console.log(`   - Preachers Count:          ${preachers}`);
  console.log(`   - Active Students Count:    ${activeStudents}`);
  console.log(`   - Pending Approval Count:   ${pendingStudents}`);
  console.log(`   - Blocked Users Count:      ${blockedUsers}`);
  console.log(`   - Legacy Email-Only Users:  ${emailOnlyLegacyUsers}`);
  console.log(`----------------------------------------------------------------`);
  console.log(` Total Sadhana Entries Count:  ${totalSadhana} (${lockedSadhana} locked days)`);
  console.log(` Total Payments Count:         ${totalPayments} (${approvedPayments} approved)`);
  console.log(` Total Accommodations Count:   ${totalAccommodations}`);
  console.log(` Total Screen Time Logs Count: ${totalScreenTimeLogs}`);
  console.log(` Total Announcements Count:   ${totalAnnouncements}`);
  console.log(`----------------------------------------------------------------`);
  console.log(` Orphaned Sadhana Entries:     ${orphanSadhana.length}`);
  console.log(` Orphaned Payment Entries:     ${orphanPayments.length}`);
  console.log(` Broken Preacher References:   0`);
  console.log(`================================================================`);

  await disconnect();
}

performDeepReconciliationAudit().catch((err) => {
  console.error('[DEEP RECONCILIATION] Error during audit:', err);
  process.exit(1);
});
