import {
  Injectable,
  ForbiddenException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { SadhanaEntry, SadhanaEntryDocument } from '../database/schemas/sadhana-entries.schema';
import { User, UserDocument } from '../database/schemas/users.schema';
import { Appointment, AppointmentDocument } from '../database/schemas/appointments.schema';
import { LogSadhanaDto } from './dto/log-sadhana.dto';
import { LockDayDto } from './dto/lock-day.dto';

@Injectable()
export class SadhanaService {
  constructor(
    @InjectModel(SadhanaEntry.name) private readonly sadhanaModel: Model<SadhanaEntryDocument>,
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
    @InjectModel(Appointment.name) private readonly appointmentModel: Model<AppointmentDocument>,
  ) {}

  private calculatePoints(activities: any): number {
    let points = 0;
    if (!activities) return 0;

    if (activities.wakeUpTime) points += 5;
    if (activities.sleepTime) points += 5;
    if (activities.manglaArti?.attended) points += 10;
    if (activities.chanting?.rounds) {
      points += activities.chanting.rounds >= 16 ? 10 : 5;
    }
    if (activities.onlineSession?.attended) points += 5;
    if (activities.bookReading?.bookName) points += 5;
    if (activities.service?.serviceName) points += 5;
    if (activities.templeVisit?.visited) points += 5;
    if (activities.srimadBhagavatamClass?.attended) points += 5;
    if (activities.bhagavadGitaClass?.attended) points += 5;
    if (activities.ekadashiFasting?.fastingType && activities.ekadashiFasting.fastingType !== 'No Fasting') {
      points += 10;
    }

    return points;
  }

  private computeLogicalDate(dateString: string, offsetMinutes: number = 330): Date {
    const [year, month, day] = dateString.split('-').map((v) => parseInt(v, 10));
    return new Date(Date.UTC(year, month - 1, day, 0, 0, 0) - offsetMinutes * 60_000);
  }

  async logSadhana(userId: string, dto: LogSadhanaDto) {
    const offset = dto.timezoneOffsetMinutes ?? 330;
    const logicalDate = this.computeLogicalDate(dto.dateString, offset);

    const existing = await this.sadhanaModel.findOne({
      userId,
      dateString: dto.dateString,
    }).lean();

    if (existing && existing.isLocked) {
      throw new ForbiddenException('Sadhana logging for this date has been locked by your preacher.');
    }

    // Deep merge: existing plain activities + new dto activities
    let mergedActivities: any = {};
    if (existing && existing.activities) {
      const existingAct = JSON.parse(JSON.stringify(existing.activities));
      // Remove Mongoose internal fields
      for (const key of Object.keys(existingAct)) {
        if (key.startsWith('_') || key.startsWith('$')) {
          delete existingAct[key];
        }
        if (existingAct[key] && typeof existingAct[key] === 'object' && existingAct[key]._id) {
          delete existingAct[key]._id;
        }
      }
      mergedActivities = { ...existingAct };
    }
    if (dto.activities) {
      for (const [key, value] of Object.entries(dto.activities)) {
        if (value !== null && value !== undefined) {
          if (typeof value === 'object' && mergedActivities[key] && typeof mergedActivities[key] === 'object') {
            mergedActivities[key] = { ...mergedActivities[key], ...value };
          } else {
            mergedActivities[key] = value;
          }
        }
      }
    }

    const totalPoints = this.calculatePoints(mergedActivities);

    const updatedEntry = await this.sadhanaModel.findOneAndUpdate(
      { userId, dateString: dto.dateString },
      {
        $set: {
          logicalDate,
          timezoneOffsetMinutes: offset,
          activities: mergedActivities,
          totalPoints,
        },
      },
      { new: true, upsert: true, runValidators: false },
    );

    return updatedEntry;
  }

  async handleStudentUpdate(userId: string, body: any) {
    const dateString = body.date || new Date().toISOString().split('T')[0];
    const category = body.category || 'folk_sadhna';
    const workStarted = body.work_started || body.workStarted || '';
    const workCompleted = body.work_completed || body.workCompleted || '';
    const points = body.points || 0;

    if (category === 'preacher_appointment') {
      const preacherId = body.preacher_id || body.preacherId;
      const preferredDate = body.preferredDate || body.date || dateString;
      const preferredTime = body.preferredTime || '10:00 AM';
      const reason = body.reason || body.description || 'Preacher Appointment';

      let appt: any = null;
      if (preacherId) {
        try {
          appt = await this.appointmentModel.create({
            userId,
            preacherId,
            preferredDate,
            preferredTime,
            reason,
            status: 'PENDING',
          });
        } catch (e) {
          console.error('Error creating appointment document:', e);
        }
      }

      const apptId = appt ? appt._id.toString() : Date.now().toString();
      return {
        _id: apptId,
        id: apptId,
        worker_id: userId,
        worker_name: body.worker_name || 'Member',
        preacher_name: body.preacher_name || 'Preacher',
        category: 'preacher_appointment',
        work_started: workStarted || `Appointment: ${preferredDate} @ ${preferredTime}`,
        description: body.description || `Preacher: ${body.preacher_name}\nDate: ${preferredDate}\nTime: ${preferredTime}\nPurpose: ${reason}`,
        work_completed: 'PENDING',
        is_completed: false,
        date: dateString,
        points: 0,
        created_at: appt ? (appt.createdAt ? appt.createdAt.toISOString() : new Date().toISOString()) : new Date().toISOString(),
      };
    }

    const newAct: any = {};
    const lower = (workStarted + ' ' + (body.description || '')).toLowerCase();

    if (lower.includes('wake-up') || lower.includes('wake up')) {
      let t = workCompleted;
      if (!t) {
        const match = workStarted.match(/wake-up:\s*([^)]+)/i);
        if (match) t = match[1].trim();
      }
      newAct.wakeUpTime = t || '05:30 AM';
    } else if (lower.includes('sleep')) {
      let t = workCompleted;
      if (!t) {
        const match = workStarted.match(/time:\s*([^)]+)/i);
        if (match) t = match[1].trim();
      }
      newAct.sleepTime = t || '10:00 PM';
    } else if (lower.includes('mangla')) {
      let t = workCompleted;
      if (!t) {
        const match = workStarted.match(/\(([^)]+)\)/);
        if (match) t = match[1].trim();
      }
      newAct.manglaArti = { attended: true, time: t || '04:30 AM' };
    } else if (lower.includes('chanting')) {
      const match = lower.match(/(\d+)\s*round/);
      const rounds = match ? parseInt(match[1], 10) : 16;
      newAct.chanting = { rounds };
    } else if (lower.includes('online')) {
      let t = workCompleted;
      if (!t || t.toLowerCase() === 'attended') {
        const match = workStarted.match(/\(([^)]+)\)/);
        if (match) t = match[1].trim();
      }
      newAct.onlineSession = { attended: true, timeSpan: t && t.toLowerCase() !== 'attended' ? t : '' };
    } else if (lower.includes('book')) {
      newAct.bookReading = { bookName: workStarted, pagesOrMinutes: workCompleted || '30 mins' };
    } else if (lower.includes('service')) {
      newAct.service = { serviceName: workStarted, durationMinutes: 30 };
    } else if (lower.includes('temple')) {
      newAct.templeVisit = { visited: true };
    } else if (lower.includes('bhagavatam')) {
      let t = workCompleted;
      if (!t || t.toLowerCase() === 'attended') {
        const match = workStarted.match(/\(([^)]+)\)/);
        if (match) t = match[1].trim();
      }
      newAct.srimadBhagavatamClass = { attended: true, timeSpan: t && t.toLowerCase() !== 'attended' ? t : '' };
    } else if (lower.includes('bhagavad') || lower.includes('gita')) {
      let t = workCompleted;
      if (!t || t.toLowerCase() === 'attended') {
        const match = workStarted.match(/\(([^)]+)\)/);
        if (match) t = match[1].trim();
      }
      newAct.bhagavadGitaClass = { attended: true, timeSpan: t && t.toLowerCase() !== 'attended' ? t : '' };
    } else if (lower.includes('ekadashi')) {
      let f = workCompleted;
      if (!f || f.toLowerCase() === 'fasting') {
        if (workStarted.includes(':')) {
          f = workStarted.split(':')[1].trim();
        } else {
          const match = workStarted.match(/\(([^)]+)\)/);
          if (match) f = match[1].trim();
        }
      }
      newAct.ekadashiFasting = { fastingType: f && f.toLowerCase() !== 'fasting' ? f : 'Fasting' };
    }

    const entry = await this.logSadhana(userId, {
      dateString,
      timezoneOffsetMinutes: 330,
      activities: newAct,
    });

    return {
      _id: entry._id.toString(),
      id: entry._id.toString(),
      worker_id: userId,
      worker_name: body.worker_name || 'Member',
      preacher_name: body.preacher_name || 'Preacher',
      category: category,
      work_started: workStarted,
      description: body.description || '',
      work_completed: workCompleted,
      is_completed: body.is_completed ?? true,
      date: dateString,
      points: points,
      created_at: new Date().toISOString(),
    };
  }

  async getUpdates(userOrUserId: any) {
    let currentUser: any = null;
    let userIdStr = '';

    if (userOrUserId && typeof userOrUserId === 'object') {
      currentUser = userOrUserId;
      userIdStr = (userOrUserId._id || userOrUserId.id || '').toString();
    } else if (userOrUserId && typeof userOrUserId === 'string') {
      userIdStr = userOrUserId;
      try {
        currentUser = await this.userModel.findById(userIdStr).lean();
      } catch (_) {}
    }

    if (!userIdStr && !currentUser) {
      return [];
    }

    const role = (currentUser?.role || '').toLowerCase();
    const isAdmin = role === 'admin' || currentUser?.isAdmin === true || currentUser?.is_admin === true;
    const isPreacher = role === 'preacher' || isAdmin;

    let entries: any[] = [];

    if (isAdmin) {
      entries = await this.sadhanaModel.find({}).sort({ logicalDate: -1, createdAt: -1 }).limit(500).lean();
    } else if (isPreacher) {
      const assignedStudents = await this.userModel
        .find({
          $or: [
            { preacherId: userIdStr },
            ...(currentUser?._id ? [{ preacherId: currentUser._id }] : []),
          ],
        })
        .select('_id name')
        .lean();

      const studentIds: any[] = assignedStudents.map((s) => s._id.toString());
      for (const s of assignedStudents) {
        studentIds.push(s._id);
      }
      studentIds.push(userIdStr);
      if (currentUser?._id) studentIds.push(currentUser._id);

      entries = await this.sadhanaModel
        .find({ userId: { $in: studentIds } })
        .sort({ logicalDate: -1, createdAt: -1 })
        .limit(500)
        .lean();

      if (entries.length === 0) {
        entries = await this.sadhanaModel.find({}).sort({ logicalDate: -1, createdAt: -1 }).limit(500).lean();
      }
    } else {
      entries = await this.sadhanaModel
        .find({
          $or: [
            { userId: userIdStr },
            ...(currentUser?._id ? [{ userId: currentUser._id }] : []),
          ],
        })
        .sort({ logicalDate: -1, createdAt: -1 })
        .limit(100)
        .lean();
    }

    // Fetch appointments from MongoDB appointments collection
    const userAppointments = await this.appointmentModel
      .find({
        $or: [
          { userId: userIdStr },
          { preacherId: userIdStr },
          ...(currentUser?._id ? [{ userId: currentUser._id }, { preacherId: currentUser._id }] : []),
        ],
      })
      .sort({ createdAt: -1 })
      .lean();

    const apptUserIds = [...new Set(userAppointments.map((a) => a.userId?.toString()).filter(Boolean))];
    const apptUsers = await this.userModel.find({ _id: { $in: apptUserIds } }).select('_id name email').lean();
    const apptUserMap = new Map(apptUsers.map((u) => [u._id.toString(), u]));

    const mappedAppointments = userAppointments.map((a) => {
      const uId = a.userId ? a.userId.toString() : '';
      const uObj = apptUserMap.get(uId);
      const studentName = uObj ? uObj.name : 'Student';
      const status = a.status || 'PENDING';
      return {
        _id: a._id.toString(),
        id: a._id.toString(),
        worker_id: uId,
        worker_name: studentName,
        student_name: studentName,
        name: studentName,
        category: 'preacher_appointment',
        work_started: `Appointment: ${a.preferredDate} @ ${a.preferredTime}`,
        description: a.reason ? `Date: ${a.preferredDate}\nTime: ${a.preferredTime}\nPurpose: ${a.reason}` : '',
        work_completed: status,
        is_completed: status === 'APPROVED' || status === 'REJECTED',
        date: a.preferredDate,
        points: 0,
        created_at: (a as any).createdAt ? new Date((a as any).createdAt).toISOString() : new Date().toISOString(),
      };
    });

    const targetUserIds = [...new Set(entries.map((e) => (e.userId ? e.userId.toString() : '')).filter(Boolean))];
    const users = await this.userModel.find({ _id: { $in: targetUserIds } }).select('_id name email').lean();
    const userMap = new Map(users.map((u) => [u._id.toString(), u]));

    const mappedSadhana = entries.map((e) => {
      const uId = e.userId ? e.userId.toString() : '';
      const uObj = userMap.get(uId);
      const studentName = uObj ? uObj.name : (e.userName || 'Student');
      return {
        _id: e._id ? e._id.toString() : '',
        id: e._id ? e._id.toString() : '',
        worker_id: uId,
        worker_name: studentName,
        student_name: studentName,
        name: studentName,
        category: 'folk_sadhna',
        date: e.dateString,
        points: e.totalPoints || 0,
        activities: e.activities || {},
        is_completed: true,
        created_at: e.logicalDate ? new Date(e.logicalDate).toISOString() : new Date().toISOString(),
      };
    });

    return [...mappedAppointments, ...mappedSadhana];
  }

  async updateStudentUpdate(id: string, body: any) {
    return {
      _id: id,
      id,
      ...body,
      is_completed: true,
    };
  }

  async deleteUpdate(id: string, label?: string, activityKey?: string) {
    let deleted = false;
    let entry: SadhanaEntryDocument | null = null;

    if (id.includes('-') && id.length <= 10) {
      entry = await this.sadhanaModel.findOne({ dateString: id });
    } else {
      try {
        entry = await this.sadhanaModel.findById(id);
      } catch (_) {
        entry = await this.sadhanaModel.findOne({ _id: id });
      }
    }

    if (!entry) {
      return { success: false, message: 'Record not found' };
    }

    const key = activityKey || this.determineActivityKeyFromLabel(label || '');

    if (key && entry.activities && (entry.activities as any)[key] !== undefined) {
      const act = JSON.parse(JSON.stringify(entry.activities));
      delete act[key];
      for (const k of Object.keys(act)) {
        if (k.startsWith('_') || k.startsWith('$')) delete act[k];
      }

      const activeKeys = Object.keys(act).filter((k) => {
        const val = act[k];
        if (val === null || val === undefined) return false;
        if (typeof val === 'object') {
          if (k === 'chanting' && (!val.rounds || val.rounds === 0)) return false;
          if (k === 'manglaArti' && val.attended !== true) return false;
          if (k === 'onlineSession' && val.attended !== true) return false;
          if (k === 'bookReading' && (!val.bookName || val.bookName.trim() === '')) return false;
          if (k === 'service' && (!val.serviceName || val.serviceName.trim() === '')) return false;
          if (k === 'templeVisit' && val.visited !== true) return false;
          if (k === 'srimadBhagavatamClass' && val.attended !== true) return false;
          if (k === 'bhagavadGitaClass' && val.attended !== true) return false;
          if (k === 'ekadashiFasting' && (!val.fastingType || val.fastingType === 'No Fasting')) return false;
        }
        return true;
      });

      if (activeKeys.length === 0) {
        await this.sadhanaModel.deleteOne({ _id: entry._id });
        deleted = true;
      } else {
        const totalPoints = this.calculatePoints(act);
        await this.sadhanaModel.updateOne(
          { _id: entry._id },
          {
            $unset: { [`activities.${key}`]: 1 },
            $set: { totalPoints },
          },
        );
        deleted = true;
      }
    } else {
      await this.sadhanaModel.deleteOne({ _id: entry._id });
      deleted = true;
    }
    return { success: true, id, deleted };
  }

  private determineActivityKeyFromLabel(label: string): string | null {
    const lower = label.toLowerCase().trim();
    if (!lower) return null;
    if (lower.includes('wake-up') || lower.includes('wake up') || lower.startsWith('morning')) return 'wakeUpTime';
    if (lower.startsWith('sleep')) return 'sleepTime';
    if (lower.includes('mangla')) return 'manglaArti';
    if (lower.startsWith('chanting')) return 'chanting';
    if (lower.startsWith('online')) return 'onlineSession';
    if (lower.startsWith('book reading') || lower.startsWith('book')) return 'bookReading';
    if (lower.startsWith('service')) return 'service';
    if (lower.startsWith('temple')) return 'templeVisit';
    if (lower.includes('bhagavatam')) return 'srimadBhagavatamClass';
    if (lower.includes('bhagavad') || lower.includes('gita')) return 'bhagavadGitaClass';
    if (lower.includes('ekadashi')) return 'ekadashiFasting';
    return null;
  }

  async getHistory(userId: string, page = 1, limit = 30) {
    const skip = (page - 1) * limit;
    const items = await this.sadhanaModel
      .find({ userId })
      .sort({ logicalDate: -1 })
      .skip(skip)
      .limit(limit);

    const total = await this.sadhanaModel.countDocuments({ userId });

    return {
      items,
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getByDate(userId: string, dateString: string) {
    const entry = await this.sadhanaModel.findOne({ userId, dateString });
    if (!entry) {
      return { userId, dateString, logged: false, activities: {} };
    }
    return entry;
  }

  async lockOrUnlockDay(preacherId: string, dto: LockDayDto) {
    const entry = await this.sadhanaModel.findOneAndUpdate(
      { userId: dto.userId, dateString: dto.dateString },
      {
        $set: {
          isLocked: dto.isLocked,
          unlockedBy: dto.isLocked ? null : preacherId,
        },
      },
      { new: true, upsert: true },
    );
    return entry;
  }
}
