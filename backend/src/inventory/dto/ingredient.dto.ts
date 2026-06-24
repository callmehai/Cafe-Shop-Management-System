import { IsNumber, IsOptional, IsString, MaxLength, Min } from 'class-validator';
import { Transform, Type } from 'class-transformer';
import { PartialType } from '@nestjs/mapped-types';

export class CreateIngredientDto {
  @Transform(({ value }) => value?.trim())
  @IsString()
  @MaxLength(50)
  name: string;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  quantityOnHand: number;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  reorderThreshold: number;
}

export class UpdateIngredientDto extends PartialType(CreateIngredientDto) {}
