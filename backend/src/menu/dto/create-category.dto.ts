import { IsString, MaxLength } from 'class-validator';
import { Transform } from 'class-transformer';

export class CreateCategoryDto {
  @Transform(({ value }) => value?.trim()) // CR-08
  @IsString()
  @MaxLength(30, { message: 'Exceed max length of 30.' }) // MSG02
  name: string;
}
