import { Model, Types } from 'mongoose';
import { UserDocument } from '../database/schemas/users.schema';
import { SadhanaEntryDocument } from '../database/schemas/sadhana-entries.schema';
import { PreachersService } from './preachers.service';
import { RealtimeService } from '../realtime/realtime.service';

describe('PreachersService', () => {
  let userModel: any;
  let sadhanaModel: any;
  let realtimeService: any;
  let service: PreachersService;

  beforeEach(() => {
    userModel = {
      find: jest.fn(),
      findById: jest.fn(),
      findOne: jest.fn(),
    };
    sadhanaModel = {
      find: jest.fn(),
    };
    realtimeService = {
      emit: jest.fn(),
    };
    service = new PreachersService(
      userModel as unknown as Model<UserDocument>,
      sadhanaModel as unknown as Model<SadhanaEntryDocument>,
      realtimeService as unknown as RealtimeService,
    );
  });

  it('getMyStudents returns students list for regular preacher with safe ObjectId / Firebase UID matchers', async () => {
    const preacherOid = new Types.ObjectId();
    const mockPreacher = {
      _id: preacherOid,
      role: 'preacher',
      firebaseUid: 'firebase-uid-test-1234',
      canViewAllStudents: false,
    };

    const mockStudents = [
      {
        _id: new Types.ObjectId(),
        name: 'Student 1',
        email: 'student1@test.com',
        role: 'folk_boy',
        status: 'ACTIVE',
        preacherId: preacherOid,
      },
    ];

    const queryChain = {
      populate: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      sort: jest.fn().mockReturnThis(),
      lean: jest.fn().mockResolvedValue(mockStudents),
    };
    userModel.find.mockReturnValue(queryChain);

    const result = await service.getMyStudents(mockPreacher);

    expect(result.total).toBe(1);
    expect(result.pendingCount).toBe(0);
    expect(result.students[0].name).toBe('Student 1');
    expect(result.students[0].id).toBe(mockStudents[0]._id.toString());
    expect(result.canViewAll).toBe(false);
    expect(result.availablePreachers).toEqual([]);
    expect(userModel.find).toHaveBeenCalledWith(
      expect.objectContaining({
        $or: expect.arrayContaining([
          { preacherId: preacherOid.toString() },
          { preacherId: expect.any(Types.ObjectId) },
          { preacherId: 'firebase-uid-test-1234' },
        ]),
      }),
    );
  });

  it('getMyStudents gracefully falls back when populate fails', async () => {
    const preacherOid = new Types.ObjectId();
    const mockPreacher = {
      _id: preacherOid,
      role: 'preacher',
      firebaseUid: 'preacher-uid-1',
      canViewAllStudents: false,
    };

    const mockFallbackStudents = [
      {
        _id: new Types.ObjectId(),
        name: 'Student Legacy',
        email: 'legacy@test.com',
        role: 'folk_boy',
        status: 'PENDING_APPROVAL',
        preacherId: 'legacy-string-id',
      },
    ];

    const failingQueryChain = {
      populate: jest.fn().mockImplementation(() => {
        throw new Error('Cast to ObjectId failed in populate');
      }),
    };

    const fallbackQueryChain = {
      select: jest.fn().mockReturnThis(),
      sort: jest.fn().mockReturnThis(),
      lean: jest.fn().mockResolvedValue(mockFallbackStudents),
    };

    userModel.find
      .mockReturnValueOnce(failingQueryChain)
      .mockReturnValueOnce(fallbackQueryChain);

    const result = await service.getMyStudents(mockPreacher);

    expect(result.total).toBe(1);
    expect(result.pendingCount).toBe(1);
    expect(result.students[0].name).toBe('Student Legacy');
  });

  it('getMyStudents safely handles active preachers without throwing when canViewAll is true', async () => {
    const mockAdmin = {
      _id: new Types.ObjectId(),
      role: 'admin',
      canViewAllStudents: true,
    };

    const mockPreachersList = [
      { _id: new Types.ObjectId(), name: 'Preacher A', email: 'a@test.com', preacherCode: 'PRA' },
      { id: 'custom-preacher-id', name: 'Preacher B', email: 'b@test.com', preacherCode: 'PRB' },
    ];

    const preachersQueryChain = {
      select: jest.fn().mockReturnThis(),
      sort: jest.fn().mockReturnThis(),
      lean: jest.fn().mockResolvedValue(mockPreachersList),
    };

    const studentsQueryChain = {
      populate: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      sort: jest.fn().mockReturnThis(),
      lean: jest.fn().mockResolvedValue([]),
    };

    userModel.find
      .mockReturnValueOnce(preachersQueryChain)
      .mockReturnValueOnce(studentsQueryChain);

    const result = await service.getMyStudents(mockAdmin, 'all');

    expect(result.canViewAll).toBe(true);
    expect(result.availablePreachers.length).toBe(2);
    expect(result.availablePreachers[0].name).toBe('Preacher A');
    expect(result.availablePreachers[1].name).toBe('Preacher B');
  });
});
