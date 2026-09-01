import { Controller, Get, Patch, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { UpdateUserProfileDto } from './dto/update-user-profile.dto';
import { FirebaseAuthGuard } from '../common/guards/firebase-auth.guard';
import { ActiveUserGuard } from '../common/guards/active-user.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Users Profile')
@Controller('users')
@UseGuards(FirebaseAuthGuard, ActiveUserGuard)
@ApiBearerAuth('access-token')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Get current authenticated user profile' })
  async getMyProfile(@CurrentUser() user: any) {
    return this.usersService.getProfile(user._id);
  }

  @Patch('me')
  @ApiOperation({ summary: 'Update profile details (name, photo, email, dob, joining date)' })
  async updateMyProfile(@CurrentUser() user: any, @Body() dto: UpdateUserProfileDto) {
    return this.usersService.updateProfile(user._id, dto);
  }
}
