import { IsEnum, IsInt, IsNumber, IsOptional, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { PaymentMethod } from '@prisma/client';

export class CreatePaymentDto {
  @Type(() => Number)
  @IsInt()
  orderId: number;

  // BR-03: một phương thức duy nhất cho mỗi order.
  @IsEnum(PaymentMethod)
  method: PaymentMethod;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  customerId?: number;

  // Loyalty redeem (BR-11): số điểm dùng để giảm giá (1 điểm = 100₫).
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  pointsRedeemed?: number;

  // Giảm giá thủ công (số tiền). Cộng dồn với giảm giá loyalty.
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  discount?: number;

  // Tiền khách đưa (CASH) — để tính tiền thối, không lưu DB.
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  cashTendered?: number;

  // BR-06: id Manager/Admin duyệt khi tổng giảm giá > 50% subtotal.
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  approvalManagerId?: number;
}
