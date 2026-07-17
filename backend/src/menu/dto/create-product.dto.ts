import { IsBoolean, IsInt, IsNumber, IsOptional, IsString, MaxLength, Min } from 'class-validator';
import { Transform, Type } from 'class-transformer';

export class CreateProductDto {
  @Transform(({ value }) => value?.trim()) // CR-08
  @IsString()
  @MaxLength(30, { message: 'Exceed max length of 30.' }) // MSG02
  name: string;

  @Type(() => Number)
  @IsInt({ message: 'Category is required.' })
  categoryId: number;

  // MSG08: Price bắt buộc + là số tiền hợp lệ (>= 0, tối đa 2 chữ số thập phân).
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 }, { message: 'The Price field is required.' })
  @Min(0, { message: 'Price must be 0 or greater.' })
  price: number;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  size?: string; // vd "S/M/L"

  @IsOptional()
  @Transform(({ value }) => value?.trim())
  @IsString()
  @MaxLength(200)
  description?: string;

  @IsOptional()
  @IsBoolean()
  isAvailable?: boolean; // BR-04: hiển thị trên order menu hay không

  @IsOptional()
  @IsString()
  imageUrl?: string;
}
