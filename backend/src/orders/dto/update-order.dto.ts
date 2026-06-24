import { ArrayMinSize, IsArray, IsInt, IsOptional, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { CreateOrderItemDto } from './create-order-item.dto';

// UC07 Update Order — chỉ khi OPEN (BR-07). Có item nào thì thay toàn bộ danh sách item.
export class UpdateOrderDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  tableId?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  customerId?: number;

  @IsOptional()
  @IsArray()
  @ArrayMinSize(1, { message: 'An order needs at least one item.' }) // BR-01
  @ValidateNested({ each: true })
  @Type(() => CreateOrderItemDto)
  items?: CreateOrderItemDto[];
}
