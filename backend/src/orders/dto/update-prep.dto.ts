import { IsEnum } from 'class-validator';
import { PrepStatus } from '@prisma/client';

// UC12: cập nhật trạng thái chuẩn bị 1 món.
export class UpdatePrepDto {
  @IsEnum(PrepStatus)
  status: PrepStatus;
}
