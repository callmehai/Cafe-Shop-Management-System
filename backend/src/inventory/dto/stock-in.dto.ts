import { ArrayMinSize, IsArray, IsInt, IsNumber, IsString, MaxLength, Min, ValidateNested } from 'class-validator';
import { Transform, Type } from 'class-transformer';

export class StockInLineDto {
  @Type(() => Number)
  @IsInt()
  ingredientId: number;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  quantity: number;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  unitCost: number;
}

// Goods receipt: tạo Purchase Order + cộng kho trong 1 bước (schema không có bảng PO-line riêng).
export class StockInDto {
  @Transform(({ value }) => value?.trim())
  @IsString()
  @MaxLength(100)
  supplierName: string;

  @IsArray()
  @ArrayMinSize(1, { message: 'Add at least one line item.' })
  @ValidateNested({ each: true })
  @Type(() => StockInLineDto)
  items: StockInLineDto[];
}
