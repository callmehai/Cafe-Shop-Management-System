import { IsEnum, IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';
import { Transform, Type } from 'class-transformer';
import { OccupancyStatus } from '@prisma/client';

export class CreateTableDto {
  @Type(() => Number)
  @IsInt({ message: 'Table number is required.' })
  @Min(1)
  number: number;

  @Type(() => Number)
  @IsInt()
  @Min(1, { message: 'Capacity must be at least 1.' })
  @Max(50)
  capacity: number;

  @IsOptional()
  @Transform(({ value }) => value?.trim())
  @IsString()
  @MaxLength(30)
  floor?: string; // "zone" trên UI: Main floor / Terrace

  @IsOptional()
  @IsString()
  @MaxLength(20)
  shape?: string; // Square / Round / Booth / Bar

  @IsOptional()
  @IsEnum(OccupancyStatus)
  occupancyStatus?: OccupancyStatus;
}
