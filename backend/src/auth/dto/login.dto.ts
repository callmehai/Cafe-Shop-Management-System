import { IsString, MaxLength, MinLength } from 'class-validator';
import { Transform } from 'class-transformer';

export class LoginDto {
  @Transform(({ value }) => value?.trim()) // CR-08
  @IsString()
  @MaxLength(20)
  username: string;

  @IsString()
  @MinLength(1)
  @MaxLength(20)
  password: string;
}
