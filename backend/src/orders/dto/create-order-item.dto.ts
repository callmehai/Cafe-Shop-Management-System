import { IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateOrderItemDto {
  @Type(() => Number)
  @IsInt()
  productId: number;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  quantity: number;

  // size / sugar level / notes gộp thành 1 chuỗi mô tả (vd "M · Sugar 50% · extra hot").
  @IsOptional()
  @IsString()
  @MaxLength(200)
  options?: string;
}
