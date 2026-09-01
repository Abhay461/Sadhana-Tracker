import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { EventsService } from './events.service';
import { CreateEventDto } from './dto/create-event.dto';
import { RegisterEventDto } from './dto/register-event.dto';
import { FirebaseAuthGuard } from '../common/guards/firebase-auth.guard';
import { ActiveUserGuard } from '../common/guards/active-user.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';

@ApiTags('Events & Programs')
@Controller('events')
@UseGuards(FirebaseAuthGuard, ActiveUserGuard)
@ApiBearerAuth('access-token')
export class EventsController {
  constructor(private readonly eventsService: EventsService) {}

  @Get()
  @ApiOperation({ summary: 'Get active upcoming events' })
  async getActiveEvents() {
    return this.eventsService.getActiveEvents();
  }

  @Post()
  @UseGuards(RolesGuard)
  @Roles('preacher', 'admin')
  @ApiOperation({ summary: 'Create a new event (Preacher/Admin only)' })
  async createEvent(@CurrentUser() user: any, @Body() dto: CreateEventDto) {
    return this.eventsService.createEvent(user, dto);
  }

  @Post(':id/register')
  @ApiOperation({ summary: 'Register current user for an event' })
  async registerForEvent(
    @CurrentUser() user: any,
    @Param('id') eventId: string,
    @Body() dto: RegisterEventDto,
  ) {
    return this.eventsService.registerForEvent(user._id, eventId, dto);
  }

  @Get(':id/registrations')
  @UseGuards(RolesGuard)
  @Roles('preacher', 'admin')
  @ApiOperation({ summary: 'Get event registrations list (Preacher/Admin only)' })
  async getEventRegistrations(@Param('id') eventId: string) {
    return this.eventsService.getEventRegistrations(eventId);
  }
}
