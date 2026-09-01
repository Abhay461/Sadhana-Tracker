import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Event, EventDocument } from '../database/schemas/events.schema';
import { EventRegistration, EventRegistrationDocument } from '../database/schemas/event-registrations.schema';
import { CreateEventDto } from './dto/create-event.dto';
import { RegisterEventDto } from './dto/register-event.dto';

@Injectable()
export class EventsService {
  constructor(
    @InjectModel(Event.name) private readonly eventModel: Model<EventDocument>,
    @InjectModel(EventRegistration.name) private readonly registrationModel: Model<EventRegistrationDocument>,
  ) {}

  async createEvent(creatorUser: any, dto: CreateEventDto) {
    const event = await this.eventModel.create({
      ...dto,
      createdBy: creatorUser._id,
      isActive: true,
    });
    return event;
  }

  async getActiveEvents() {
    return this.eventModel.find({ isActive: true }).sort({ eventDate: 1 });
  }

  async registerForEvent(userId: string, eventId: string, dto: RegisterEventDto) {
    const event = await this.eventModel.findById(eventId);
    if (!event || !event.isActive) {
      throw new NotFoundException('Event not found or inactive.');
    }

    const existing = await this.registrationModel.findOne({ eventId, userId });
    if (existing) {
      throw new ConflictException('You are already registered for this event.');
    }

    const registration = await this.registrationModel.create({
      eventId,
      userId,
      registeredName: dto.registeredName,
      contactNumber: dto.contactNumber,
      registrationStatus: 'REGISTERED',
      registeredAt: new Date(),
    });

    return {
      registration,
      registrationLink: event.registrationLink,
    };
  }

  async getEventRegistrations(eventId: string) {
    return this.registrationModel
      .find({ eventId })
      .populate('userId', 'name email phoneNumber photoUrl')
      .sort({ registeredAt: -1 });
  }
}
