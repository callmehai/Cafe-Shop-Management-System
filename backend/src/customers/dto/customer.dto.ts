import { IsEmail, IsOptional, IsString, MaxLength } from 'class-validator';
import { Transform } from 'class-transformer';
import { PartialType } from '@nestjs/mapped-types';

export class CreateCustomerDto {
  @Transform(({ value }) => value?.trim())
  @IsString()
  @MaxLength(80)
  fullName: string;

  @IsOptional()
  @Transform(({ value }) => value?.trim())
  @IsString()
  @MaxLength(20)
  phone?: string;

  @IsOptional()
  @Transform(({ value }) => value?.trim())
  @IsEmail({}, { message: 'Enter a valid email.' })
  email?: string;
}

export class UpdateCustomerDto extends PartialType(CreateCustomerDto) {}
