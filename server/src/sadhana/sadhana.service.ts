import {
  Injectable,
  ForbiddenException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { SadhanaEntry, SadhanaEntryDocument } from '../database/schemas/sadhana-entries.schema';
import { User, UserDocument } from '../database/schemas/users.schema';
import { Appointment, AppointmentDocument } from '../database/schemas/appointments.schema';
import { LogSadhanaDto } from './dto/log-sadhana.dto';
import { LockDayDto } from './dto/lock-day.dto';
import { RealtimeService } from '../realtime/realtime.service';

@Injectable()
export class SadhanaService {
  constructor(
    @InjectModel(SadhanaEntry.name) private readonly sadhanaModel: Model<SadhanaEntryDocument>,
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
    @InjectModel(Appointment.name) private readonly appointmentModel: Model<AppointmentDocument>,
    private readonly realtimeService: RealtimeService,
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

    this.realtimeService.emit('sadhana_update', 'create', updatedEntry, { studentId: userId });
    return updatedEntry;
  }

  async handleStudentUpdate(userId: string, body: any) {
    const dateString = body.date || new Date().toISOString().split('T')[0];
    const category = body.category || 'folk_sadhna';
    const workStarted = body.work_started || body.workStarted || '';
    const workCompleted = body.work_completed || body.workCompleted || '';
    const points = body.points || 0;

    if (category === 'preacher_appointment') {
      let preacherIdRaw = body.preacher_id || body.preacherId;
      if (!preacherIdRaw || !Types.ObjectId.isValid(preacherIdRaw)) {
        const studentUser = await this.userModel.findById(userId).lean();
        if (studentUser?.preacherId && Types.ObjectId.isValid(studentUser.preacherId.toString())) {
          preacherIdRaw = studentUser.preacherId.toString();
        } else {
          const defaultPreacher = await this.userModel.findOne({ role: { $in: ['preacher', 'admin'] } }).select('_id').lean();
          if (defaultPreacher) {
            preacherIdRaw = defaultPreacher._id.toString();
          }
        }
      }

      const preferredDate = body.preferredDate || body.date || dateString;
      const preferredTime = body.preferredTime || '10:00 AM';
      const reason = body.reason || body.description || 'Preacher Appointment';

      let appt: any = null;
      if (preacherIdRaw && Types.ObjectId.isValid(preacherIdRaw)) {
        try {
          appt = await this.appointmentModel.create({
            userId,
            preacherId: preacherIdRaw,
            preferredDate,
            preferredTime,
            reason,
            status: 'PENDING',
          });
          console.log('📌 [APPOINTMENT MONGO DOCUMENT CREATED]:', appt);
        } catch (e) {
          console.error('Error creating appointment document:', e);
        }
      }

      const apptId = appt ? appt._id.toString() : Date.now().toString();
      const responsePayload = {
        _id: apptId,
        id: apptId,
        worker_id: userId,
        studentId: userId,
        preacherId: preacherIdRaw,
        worker_name: body.worker_name || 'Member',
        preacher_name: body.preacher_name || 'Preacher',
        category: 'preacher_appointment',
        work_started: workStarted || `Appointment: ${preferredDate} @ ${preferredTime}`,
        description: body.description || `Preacher: ${body.preacher_name}\nDate: ${preferredDate}\nTime: ${preferredTime}\nPurpose: ${reason}`,
        work_completed: 'PENDING',
        status: 'PENDING',
        is_completed: false,
        date: dateString,
        points: 0,
        created_at: appt ? (appt.createdAt ? appt.createdAt.toISOString() : new Date().toISOString()) : new Date().toISOString(),
      };
      console.log('📌 [APPOINTMENT CREATION RESPONSE]:', JSON.stringify({
        appointmentId: apptId,
        studentId: userId,
        preacherId: preacherIdRaw,
        response: responsePayload,
      }));
      this.realtimeService.emit('appointment_update', 'create', responsePayload, {
        preacherId: preacherIdRaw,
        studentId: userId,
      });
      return responsePayload;
    }

    if (category === 'accommodation' || category === 'residency_admission' || category === 'payment') {
      const payload = {
        _id: Date.now().toString(),
        id: Date.now().toString(),
        worker_id: userId,
        worker_name: body.worker_name || 'Member',
        preacher_name: body.preacher_name || 'Preacher',
        category: category,
        work_started: workStarted,
        description: body.description || '',
        work_completed: workCompleted || 'PENDING',
        is_completed: body.is_completed ?? false,
        date: dateString,
        points: points,
        created_at: new Date().toISOString(),
      };

      const eventType = category === 'accommodation' ? 'accommodation_update' : (category === 'payment' ? 'payment_update' : 'sadhana_update');
      this.realtimeService.emit(eventType, 'create', payload, { studentId: userId });
      return payload;
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
    } else if ((lower.includes('book reading') || lower.includes('reading') || lower.includes('book')) && !lower.includes('accommodation') && !lower.includes('booking')) {
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
    const canViewAll = Boolean(
      isAdmin || currentUser?.canViewAllStudents || currentUser?.isHeadPreacher
    );
    const isPreacher = role === 'preacher' || isAdmin;

    let entries: any[] = [];

    if (canViewAll) {
      entries = await this.sadhanaModel.find({}).sort({ logicalDate: -1, createdAt: -1 }).limit(1000).lean();
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
    let userAppointments: any[] = [];
    const userOrIdConditions: any[] = [
      { userId: userIdStr },
      { preacherId: userIdStr },
    ];
    if (Types.ObjectId.isValid(userIdStr)) {
      const objId = new Types.ObjectId(userIdStr);
      userOrIdConditions.push({ userId: objId });
      userOrIdConditions.push({ preacherId: objId });
    }
    if (currentUser?._id) {
      userOrIdConditions.push({ userId: currentUser._id });
      userOrIdConditions.push({ preacherId: currentUser._id });
    }

    if (canViewAll) {
      userAppointments = await this.appointmentModel.find({}).sort({ createdAt: -1 }).limit(1000).lean();
    } else if (isPreacher) {
      const assignedStudents = await this.userModel
        .find({
          $or: [
            { preacherId: userIdStr },
            ...(currentUser?._id ? [{ preacherId: currentUser._id }] : []),
          ],
        })
        .select('_id')
        .lean();
      const ids: any[] = assignedStudents.map((s) => s._id);
      ids.push(userIdStr);
      if (currentUser?._id) ids.push(currentUser._id);
      if (Types.ObjectId.isValid(userIdStr)) ids.push(new Types.ObjectId(userIdStr));

      userAppointments = await this.appointmentModel
        .find({
          $or: [
            { preacherId: { $in: ids } },
            { userId: { $in: ids } },
          ],
        })
        .sort({ createdAt: -1 })
        .limit(500)
        .lean();
    } else {
      userAppointments = await this.appointmentModel
        .find({ $or: userOrIdConditions })
        .sort({ createdAt: -1 })
        .limit(100)
        .lean();
    }

    const apptUserIds = [...new Set(userAppointments.map((a) => a.userId?.toString()).filter(Boolean))];
    const apptUsers = await this.userModel.find({ _id: { $in: apptUserIds } }).select('_id name email').lean();
    const apptUserMap = new Map(apptUsers.map((u) => [u._id.toString(), u]));

    const mappedAppointments = userAppointments.map((a) => {
      const uId = a.userId ? a.userId.toString() : '';
      const pId = a.preacherId ? a.preacherId.toString() : '';
      const uObj = apptUserMap.get(uId);
      const studentName = uObj ? uObj.name : 'Student';
      const status = (a.status || 'PENDING').toUpperCase();
      const apptId = a._id.toString();
      const finalDate = a.approvedDate || a.preferredDate;
      const finalTime = a.approvedTime || a.preferredTime;
      return {
        _id: apptId,
        id: apptId,
        appointmentId: apptId,
        worker_id: uId,
        studentId: uId,
        preacherId: pId,
        worker_name: studentName,
        student_name: studentName,
        name: studentName,
        category: 'preacher_appointment',
        preferredDate: a.preferredDate,
        preferredTime: a.preferredTime,
        approvedDate: a.approvedDate || null,
        approvedTime: a.approvedTime || null,
        finalDate: finalDate,
        finalTime: finalTime,
        work_started: `Appointment: ${finalDate} @ ${finalTime}`,
        description: a.reason ? `Date: ${finalDate}\nTime: ${finalTime}\nPurpose: ${a.reason}` : `Date: ${finalDate}\nTime: ${finalTime}`,
        work_completed: status,
        status: status,
        is_completed: status === 'APPROVED' || status === 'REJECTED',
        date: finalDate,
        points: 0,
        created_at: (a as any).createdAt ? new Date((a as any).createdAt).toISOString() : new Date().toISOString(),
      };
    });

    console.log(`📌 [APPOINTMENT RETRIEVAL RESPONSE/COUNT]: User=${userIdStr}, Count=${mappedAppointments.length}, Items=`,
      mappedAppointments.map(a => ({ appointmentId: a.id, studentId: a.studentId, preacherId: a.preacherId, status: a.status }))
    );

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
    console.log(`📌 [BACKEND PATCH /sadhana/updates/${id}] Request Body:`, JSON.stringify(body));

    let status = 'APPROVED';
    if (body.status) {
      status = body.status.toString().toUpperCase();
    } else if (body.work_completed === 'REJECTED' || body.workCompleted === 'REJECTED' || body.approved === false) {
      status = 'REJECTED';
    } else if (body.work_completed === 'APPROVED' || body.workCompleted === 'APPROVED' || body.approved === true) {
      status = 'APPROVED';
    } else if (body.is_completed === true) {
      status = 'APPROVED';
    }

    if (status !== 'APPROVED' && status !== 'REJECTED') {
      status = 'APPROVED';
    }

    if (Types.ObjectId.isValid(id)) {
      const existingAppt = await this.appointmentModel.findById(id);
      if (existingAppt) {
        existingAppt.status = status;

        if (status === 'APPROVED') {
          const appDate = body.approvedDate || body.preferredDate || existingAppt.preferredDate;
          const appTime = body.approvedTime || body.preferredTime || existingAppt.preferredTime;
          existingAppt.approvedDate = appDate;
          existingAppt.approvedTime = appTime;
        }

        await existingAppt.save();
        console.log(`📌 [APPOINTMENT MONGO UPDATED SUCCESSFULLY]: ID=${id}, FinalStatus=${existingAppt.status}, ApprovedDate=${existingAppt.approvedDate}, ApprovedTime=${existingAppt.approvedTime}`);

        const updatedDoc = await this.appointmentModel.findById(id).lean();
        const finalDate = updatedDoc.approvedDate || updatedDoc.preferredDate;
        const finalTime = updatedDoc.approvedTime || updatedDoc.preferredTime;

        const response = {
          _id: updatedDoc._id.toString(),
          id: updatedDoc._id.toString(),
          appointmentId: updatedDoc._id.toString(),
          userId: updatedDoc.userId?.toString(),
          worker_id: updatedDoc.userId?.toString(),
          studentId: updatedDoc.userId?.toString(),
          preacherId: updatedDoc.preacherId?.toString(),
          preferredDate: updatedDoc.preferredDate,
          preferredTime: updatedDoc.preferredTime,
          approvedDate: updatedDoc.approvedDate || null,
          approvedTime: updatedDoc.approvedTime || null,
          finalDate,
          finalTime,
          reason: updatedDoc.reason,
          status: updatedDoc.status,
          work_completed: updatedDoc.status,
          work_started: `Appointment: ${finalDate} @ ${finalTime}`,
          description: updatedDoc.reason ? `Date: ${finalDate}\nTime: ${finalTime}\nPurpose: ${updatedDoc.reason}` : `Date: ${finalDate}\nTime: ${finalTime}`,
          is_completed: updatedDoc.status === 'APPROVED' || updatedDoc.status === 'REJECTED',
          category: 'preacher_appointment',
          ...body,
        };
        console.log(`📌 [APPOINTMENT APPROVE/REJECT RESPONSE]:`, JSON.stringify(response));
        this.realtimeService.emit('appointment_update', 'update', response);
        return response;
      }
    }

    console.log(`📌 [UPDATE SESSIONS FALLBACK]: ID=${id}`);
    const fallbackRes = {
      _id: id,
      id,
      ...body,
      status,
      work_completed: status,
      is_completed: true,
    };
    this.realtimeService.emit('sadhana_update', 'update', fallbackRes);
    return fallbackRes;
  }

  async deleteUpdate(id: string, label?: string, activityKey?: string) {
    if (Types.ObjectId.isValid(id)) {
      const apptDoc = await this.appointmentModel.findById(id);
      if (apptDoc) {
        apptDoc.status = 'REJECTED';
        await apptDoc.save();
        console.log(`📌 [APPOINTMENT MONGO UPDATED VIA DELETE]: ID=${id}, FinalStatus=REJECTED`);
        this.realtimeService.emit('appointment_update', 'update', { id, appointmentId: id, status: 'REJECTED' });
        return { success: true, id, status: 'REJECTED' };
      }
    }

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

    let key = activityKey || this.determineActivityKeyFromLabel(label || '');

    if (!key && entry.activities) {
      const acts = entry.activities as any;
      const lowerLabel = (label || '').toLowerCase();
      if (acts.wakeUpTime && (lowerLabel.includes('wake') || lowerLabel.includes('morning'))) key = 'wakeUpTime';
      else if (acts.sleepTime && lowerLabel.includes('sleep')) key = 'sleepTime';
      else if (acts.manglaArti && lowerLabel.includes('mangla')) key = 'manglaArti';
      else if (acts.chanting && (lowerLabel.includes('chant') || lowerLabel.includes('round'))) key = 'chanting';
      else if (acts.onlineSession && lowerLabel.includes('online')) key = 'onlineSession';
      else if (acts.bookReading && (lowerLabel.includes('book') || lowerLabel.includes('read'))) key = 'bookReading';
      else if (acts.service && lowerLabel.includes('service')) key = 'service';
      else if (acts.templeVisit && lowerLabel.includes('temple')) key = 'templeVisit';
      else if (acts.srimadBhagavatamClass && lowerLabel.includes('bhagavatam')) key = 'srimadBhagavatamClass';
      else if (acts.bhagavadGitaClass && (lowerLabel.includes('bhagavad') || lowerLabel.includes('gita'))) key = 'bhagavadGitaClass';
      else if (acts.ekadashiFasting && (lowerLabel.includes('ekadashi') || lowerLabel.includes('fast'))) key = 'ekadashiFasting';
    }

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
    } else if (!label || label.trim() === '') {
      await this.sadhanaModel.deleteOne({ _id: entry._id });
      deleted = true;
    }
    const delResult = { success: true, id, deleted };
    this.realtimeService.emit('sadhana_update', 'delete', delResult);
    return delResult;
  }

  private determineActivityKeyFromLabel(label: string): string | null {
    const lower = label.toLowerCase().trim();
    if (!lower) return null;
    if (lower.includes('wake-up') || lower.includes('wake up') || lower.includes('morning') || lower.includes('wake')) return 'wakeUpTime';
    if (lower.includes('sleep')) return 'sleepTime';
    if (lower.includes('mangla')) return 'manglaArti';
    if (lower.includes('chant') || lower.includes('round')) return 'chanting';
    if (lower.includes('online')) return 'onlineSession';
    if ((lower.includes('book reading') || lower.includes('reading') || lower.includes('book')) && !lower.includes('accommodation') && !lower.includes('booking')) return 'bookReading';
    if (lower.includes('service')) return 'service';
    if (lower.includes('temple')) return 'templeVisit';
    if (lower.includes('bhagavatam')) return 'srimadBhagavatamClass';
    if (lower.includes('bhagavad') || lower.includes('gita')) return 'bhagavadGitaClass';
    if (lower.includes('ekadashi') || lower.includes('fast')) return 'ekadashiFasting';
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
    this.realtimeService.emit('sadhana_update', 'update', entry, { studentId: dto.userId });
    return entry;
  }
}
