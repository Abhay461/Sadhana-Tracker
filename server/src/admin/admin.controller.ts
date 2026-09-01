import { Controller, Get, Post, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AdminService } from './admin.service';
import { CreatePreacherDto } from './dto/create-preacher.dto';
import { FirebaseAuthGuard } from '../common/guards/firebase-auth.guard';
import { ActiveUserGuard } from '../common/guards/active-user.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';

@ApiTags('Admin Console')
@Controller('admin')
@UseGuards(FirebaseAuthGuard, ActiveUserGuard, RolesGuard)
@Roles('admin')
@ApiBearerAuth('access-token')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Post('preachers')
  @ApiOperation({ summary: 'Create a new preacher account with automatic credentials and code' })
  async createPreacher(@CurrentUser() adminUser: any, @Body() dto: CreatePreacherDto) {
    return this.adminService.createPreacher(adminUser, dto);
  }

  @Get('preachers')
  @ApiOperation({ summary: 'List all preachers and their assigned students' })
  async getAllPreachers() {
    return this.adminService.getAllPreachers();
  }
}
