import { Controller, Get, Post, Body } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { AdminService } from './admin.service';
import { CreatePreacherDto } from './dto/create-preacher.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Admin Console')
@Controller('admin')
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
