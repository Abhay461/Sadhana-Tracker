import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Course, CourseDocument } from '../database/schemas/courses.schema';
import { CreateCourseDto, CreateCourseVideoDto } from './dto/create-course.dto';

@Injectable()
export class CoursesService {
  constructor(
    @InjectModel(Course.name) private readonly courseModel: Model<CourseDocument>,
  ) {}

  async getAllCourses() {
    return this.courseModel.find({ isActive: true }).sort({ createdAt: -1 });
  }

  async getCourseById(id: string) {
    const course = await this.courseModel.findById(id);
    if (!course) throw new NotFoundException('Course not found');
    return course;
  }

  async createCourse(dto: CreateCourseDto) {
    return this.courseModel.create(dto);
  }

  async updateCourse(id: string, dto: Partial<CreateCourseDto>) {
    const updated = await this.courseModel.findByIdAndUpdate(id, dto, { new: true });
    if (!updated) throw new NotFoundException('Course not found');
    return updated;
  }

  async deleteCourse(id: string) {
    const deleted = await this.courseModel.findByIdAndUpdate(id, { isActive: false }, { new: true });
    if (!deleted) throw new NotFoundException('Course not found');
    return { message: 'Course deactivated successfully' };
  }

  async addVideoToCourse(courseId: string, videoDto: CreateCourseVideoDto) {
    const course = await this.courseModel.findById(courseId);
    if (!course) throw new NotFoundException('Course not found');

    course.videos.push(videoDto as any);
    await course.save();
    return course;
  }

  async seedDefaultCoursesIfEmpty() {
    const count = await this.courseModel.countDocuments();
    if (count > 0) return;

    const defaultCourses: Partial<Course>[] = [
      {
        title: 'Discover Yourself (DYS)',
        subtitle: 'Science of Self, Mind & Meditation',
        duration: '6 Sessions',
        category: 'Foundational',
        price: '₹499',
        originalPrice: '₹999',
        priceVal: 499,
        iconName: 'psychology_rounded',
        colorHex: '#4F46E5',
        bgHex: '#EEF2FF',
        bannerImage: 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?auto=format&fit=crop&w=600&q=80',
        description: 'Systematic course exploring life purpose, mind control, karma & meditation practices.',
        isActive: true,
        videos: [
          {
            title: 'Session 1: Can a Scientist Believe in God?',
            description: 'Introduction to science and spirituality',
            videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
            duration: '45 mins',
            isPreview: true,
            orderIndex: 1,
          },
          {
            title: 'Session 2: Science of Soul & Mind',
            description: 'Deep dive into consciousness',
            videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
            duration: '50 mins',
            isPreview: false,
            orderIndex: 2,
          },
        ],
      },
      {
        title: 'Bhagavad Gita As It Is',
        subtitle: '18 Chapters In-Depth Study',
        duration: '12 Weeks',
        category: 'Vedic Wisdom',
        price: '₹999',
        originalPrice: '₹1999',
        priceVal: 999,
        iconName: 'auto_stories_rounded',
        colorHex: '#D97706',
        bgHex: '#FFFBEB',
        bannerImage: 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=600&q=80',
        description: 'Learn timeless wisdom for daily life, duty, devotion, and inner peace.',
        isActive: true,
        videos: [],
      },
      {
        title: 'Spiritual Scientist',
        subtitle: 'Consciousness & Scientific Evidence',
        duration: '4 Sessions',
        category: 'Science & Spirituality',
        price: '₹349',
        originalPrice: '₹699',
        priceVal: 349,
        iconName: 'science_rounded',
        colorHex: '#059669',
        bgHex: '#ECFDF5',
        bannerImage: 'https://images.unsplash.com/photo-1507413245164-6160d8298b31?auto=format&fit=crop&w=600&q=80',
        description: 'Scientific inquiry into life, origin of species, consciousness, and cosmology.',
        isActive: true,
        videos: [],
      },
      {
        title: 'Japa Yoga & Habit Building',
        subtitle: 'Mastering Mantra Meditation',
        duration: '3 Weeks',
        category: 'Practicum',
        price: '₹299',
        originalPrice: '₹599',
        priceVal: 299,
        iconName: 'spa_rounded',
        colorHex: '#DB2777',
        bgHex: '#FDF2F8',
        bannerImage: 'https://images.unsplash.com/photo-1609137144813-7d9921338f24?auto=format&fit=crop&w=600&q=80',
        description: 'Practical guide to morning habits, mantra meditation focus, and spiritual discipline.',
        isActive: true,
        videos: [],
      },
    ];

    await this.courseModel.insertMany(defaultCourses);
  }
}
