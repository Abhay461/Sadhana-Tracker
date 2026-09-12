import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
} from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { CoursesService } from './courses.service';
import { CreateCourseDto, CreateCourseVideoDto } from './dto/create-course.dto';

@ApiTags('Courses & Videos')
@Controller('courses')
export class CoursesController {
  constructor(private readonly coursesService: CoursesService) {}

  @Get()
  @ApiOperation({ summary: 'Get all active courses for student mobile app & web' })
  async getAllCourses() {
    await this.coursesService.seedDefaultCoursesIfEmpty();
    return this.coursesService.getAllCourses();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get detailed course with videos by ID' })
  async getCourseById(@Param('id') id: string) {
    return this.coursesService.getCourseById(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create a new course (Admin Web Portal)' })
  async createCourse(@Body() dto: CreateCourseDto) {
    return this.coursesService.createCourse(dto);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update a course (Admin Web Portal)' })
  async updateCourse(@Param('id') id: string, @Body() dto: Partial<CreateCourseDto>) {
    return this.coursesService.updateCourse(id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete/Deactivate a course (Admin Web Portal)' })
  async deleteCourse(@Param('id') id: string) {
    return this.coursesService.deleteCourse(id);
  }

  @Post(':id/videos')
  @ApiOperation({ summary: 'Add a video lesson to course (Admin Web Portal)' })
  async addVideoToCourse(@Param('id') id: string, @Body() videoDto: CreateCourseVideoDto) {
    return this.coursesService.addVideoToCourse(id, videoDto);
  }
}
