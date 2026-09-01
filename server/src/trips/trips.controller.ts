import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { TripsService } from './trips.service';
import { CreateTripDto } from './dto/create-trip.dto';
import { RegisterTripDto } from './dto/register-trip.dto';
import { FirebaseAuthGuard } from '../common/guards/firebase-auth.guard';
import { ActiveUserGuard } from '../common/guards/active-user.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';

@ApiTags('Trips & Yatras')
@Controller('trips')
@UseGuards(FirebaseAuthGuard, ActiveUserGuard)
@ApiBearerAuth('access-token')
export class TripsController {
  constructor(private readonly tripsService: TripsService) {}

  @Get()
  @ApiOperation({ summary: 'Get active upcoming trips' })
  async getActiveTrips() {
    return this.tripsService.getActiveTrips();
  }

  @Post()
  @UseGuards(RolesGuard)
  @Roles('preacher', 'admin')
  @ApiOperation({ summary: 'Create a new trip (Preacher/Admin only)' })
  async createTrip(@CurrentUser() user: any, @Body() dto: CreateTripDto) {
    return this.tripsService.createTrip(user, dto);
  }

  @Post(':id/register')
  @ApiOperation({ summary: 'Register current user for a trip' })
  async registerForTrip(
    @CurrentUser() user: any,
    @Param('id') tripId: string,
    @Body() dto: RegisterTripDto,
  ) {
    return this.tripsService.registerForTrip(user._id, tripId, dto);
  }

  @Get(':id/registrations')
  @UseGuards(RolesGuard)
  @Roles('preacher', 'admin')
  @ApiOperation({ summary: 'Get trip registrations list (Preacher/Admin only)' })
  async getTripRegistrations(@Param('id') tripId: string) {
    return this.tripsService.getTripRegistrations(tripId);
  }
}
