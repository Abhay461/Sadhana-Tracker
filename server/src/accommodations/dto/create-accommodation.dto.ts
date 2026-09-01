import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty } from 'class-validator';

export class CreateAccommodationDto {
  @ApiProperty({ description: 'Details of accommodation request', example: 'Need room for 3 days during festival' })
  @IsString()
  @IsNotEmpty()
  requestDetails: string;
}
