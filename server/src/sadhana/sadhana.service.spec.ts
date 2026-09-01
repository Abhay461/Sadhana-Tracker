import { Model } from 'mongoose';
import { SadhanaEntryDocument } from '../database/schemas/sadhana-entries.schema';
import { SadhanaService } from './sadhana.service';

describe('SadhanaService', () => {
  const sadhanaModel = {
    findOne: jest.fn(),
    findOneAndUpdate: jest.fn(),
  };

  const service = new SadhanaService(
    sadhanaModel as unknown as Model<SadhanaEntryDocument>,
  );

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('stores a logical date at the user-local midnight expressed in UTC', async () => {
    sadhanaModel.findOne.mockResolvedValue(null);
    sadhanaModel.findOneAndUpdate.mockResolvedValue({ id: 'entry-1' });

    await service.logSadhana('user-1', {
      dateString: '2026-08-31',
      timezoneOffsetMinutes: 330,
      activities: { wakeUpTime: '04:30' },
    });

    expect(sadhanaModel.findOneAndUpdate).toHaveBeenCalledWith(
      { userId: 'user-1', dateString: '2026-08-31' },
      expect.objectContaining({
        $set: expect.objectContaining({
          logicalDate: new Date('2026-08-30T18:30:00.000Z'),
          timezoneOffsetMinutes: 330,
        }),
      }),
      { new: true, upsert: true, runValidators: true },
    );
  });
});
