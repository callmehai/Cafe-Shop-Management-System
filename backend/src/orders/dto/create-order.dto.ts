import { ArrayMinSize, IsArray, IsInt, IsOptional, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { CreateOrderItemDto } from './create-order-item.dto';

export class CreateOrderDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  tableId?: number; // null/absent = takeaway

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  customerId?: number;

  @IsArray()
  @ArrayMinSize(1, { message: 'An order needs at least one item.' }) // BR-01
  @ValidateNested({ each: true })
  @Type(() => CreateOrderItemDto)
  items: CreateOrderItemDto[];
}
