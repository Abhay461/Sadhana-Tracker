import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AccommodationsService } from './accommodations.service';
import { CreateAccommodationDto } from './dto/create-accommodation.dto';
import { UpdateAccommodationStatusDto } from './dto/update-accommodation-status.dto';
import { FirebaseAuthGuard } from '../common/guards/firebase-auth.guard';
import { ActiveUserGuard } from '../common/guards/active-user.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { OwnershipGuard } from '../common/guards/ownership.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';

@ApiTags('Accommodations')
@Controller('accommodations')
@UseGuards(FirebaseAuthGuard, ActiveUserGuard, RolesGuard, OwnershipGuard)
@ApiBearerAuth('access-token')
export class AccommodationsController {
  constructor(private readonly accommodationsService: AccommodationsService) {}

  @Post()
  @Roles('folk_boy', 'residency')
  @ApiOperation({ summary: 'Submit accommodation request' })
  async createRequest(@CurrentUser() user: any, @Body() dto: CreateAccommodationDto) {
    return this.accommodationsService.createRequest(user, dto);
  }

  @Get('my')
  @Roles('folk_boy', 'residency')
  @ApiOperation({ summary: 'Get current student accommodation requests' })
  async getMyRequests(@CurrentUser() user: any) {
    return this.accommodationsService.getMyRequests(user._id);
  }

  @Get('queue')
  @Roles('preacher', 'admin')
  @ApiOperation({ summary: 'Get preacher accommodation requests queue' })
  async getPreacherQueue(@CurrentUser() preacher: any) {
    return this.accommodationsService.getPreacherQueue(preacher._id);
  }

  @Patch(':id/status')
  @Roles('preacher', 'admin')
  @ApiOperation({ summary: 'Approve or reject accommodation request' })
  async updateStatus(
    @CurrentUser() preacher: any,
    @Param('id') id: string,
    @Body() dto: UpdateAccommodationStatusDto,
  ) {
    return this.accommodationsService.updateStatus(preacher._id, id, dto);
  }
}
