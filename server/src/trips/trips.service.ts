import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Trip, TripDocument } from '../database/schemas/trips.schema';
import { TripRegistration, TripRegistrationDocument } from '../database/schemas/trip-registrations.schema';
import { CreateTripDto } from './dto/create-trip.dto';
import { RegisterTripDto } from './dto/register-trip.dto';

@Injectable()
export class TripsService {
  constructor(
    @InjectModel(Trip.name) private readonly tripModel: Model<TripDocument>,
    @InjectModel(TripRegistration.name) private readonly registrationModel: Model<TripRegistrationDocument>,
  ) {}

  async createTrip(creatorUser: any, dto: CreateTripDto) {
    const trip = await this.tripModel.create({
      ...dto,
      createdBy: creatorUser._id,
      isActive: true,
    });
    return trip;
  }

  async getActiveTrips() {
    return this.tripModel.find({ isActive: true }).sort({ tripDate: 1 });
  }

  async registerForTrip(userId: string, tripId: string, dto: RegisterTripDto) {
    const trip = await this.tripModel.findById(tripId);
    if (!trip || !trip.isActive) {
      throw new NotFoundException('Trip not found or inactive.');
    }

    const existing = await this.registrationModel.findOne({ tripId, userId });
    if (existing) {
      throw new ConflictException('You are already registered for this trip.');
    }

    const registration = await this.registrationModel.create({
      tripId,
      userId,
      registeredName: dto.registeredName,
      contactNumber: dto.contactNumber,
      registrationStatus: 'REGISTERED',
      registeredAt: new Date(),
    });

    return {
      registration,
      registrationLink: trip.registrationLink,
    };
  }

  async getTripRegistrations(tripId: string) {
    return this.registrationModel
      .find({ tripId })
      .populate('userId', 'name email phoneNumber photoUrl')
      .sort({ registeredAt: -1 });
  }
}
