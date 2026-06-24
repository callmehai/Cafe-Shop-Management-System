import { IsBoolean, IsEnum, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { Transform } from 'class-transformer';
import { Role } from '../../common/enums/role.enum';

export class CreateUserDto {
  @Transform(({ value }) => value?.trim()) // CR-08
  @IsString() @MaxLength(50)
  fullName: string;

  @Transform(({ value }) => value?.trim())
  @IsString() @MaxLength(20)
  username: string;

  @IsString() @MinLength(6) @MaxLength(50)
  password: string;

  @IsEnum(Role)
  role: Role;

  @IsOptional() @IsBoolean()
  isActive?: boolean;
}
