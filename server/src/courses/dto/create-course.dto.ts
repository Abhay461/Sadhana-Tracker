import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateCourseVideoDto {
  @ApiProperty({ description: 'Video title' })
  title: string;

  @ApiPropertyOptional({ description: 'Video description' })
  description?: string;

  @ApiProperty({ description: 'Video streaming or YouTube URL' })
  videoUrl: string;

  @ApiPropertyOptional({ description: 'Video thumbnail image URL' })
  thumbnailUrl?: string;

  @ApiPropertyOptional({ description: 'Duration string e.g. 25 mins' })
  duration?: string;

  @ApiPropertyOptional({ description: 'Is preview video free for non-paid users?' })
  isPreview?: boolean;

  @ApiPropertyOptional({ description: 'Order index' })
  orderIndex?: number;
}

export class CreateCourseDto {
  @ApiProperty({ description: 'Course title' })
  title: string;

  @ApiPropertyOptional({ description: 'Course subtitle' })
  subtitle?: string;

  @ApiPropertyOptional({ description: 'Detailed course description' })
  description?: string;

  @ApiPropertyOptional({ description: 'Category e.g. Foundational, Vedic Wisdom' })
  category?: string;

  @ApiProperty({ description: 'Price display string e.g. ₹499' })
  price: string;

  @ApiPropertyOptional({ description: 'Original price strikethrough display string e.g. ₹999' })
  originalPrice?: string;

  @ApiProperty({ description: 'Numerical price value e.g. 499' })
  priceVal: number;

  @ApiPropertyOptional({ description: 'Course duration e.g. 6 Sessions' })
  duration?: string;

  @ApiPropertyOptional({ description: 'Banner image URL' })
  bannerImage?: string;

  @ApiPropertyOptional({ description: 'Icon name' })
  iconName?: string;

  @ApiPropertyOptional({ description: 'Color hex code' })
  colorHex?: string;

  @ApiPropertyOptional({ description: 'Background hex code' })
  bgHex?: string;

  @ApiPropertyOptional({ description: 'Array of videos/lessons', type: [CreateCourseVideoDto] })
  videos?: CreateCourseVideoDto[];
}
