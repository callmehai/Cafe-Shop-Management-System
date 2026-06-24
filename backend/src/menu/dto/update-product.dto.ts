import { PartialType } from '@nestjs/mapped-types';
import { CreateProductDto } from './create-product.dto';

// UC13 Edit Product — cập nhật từng phần (bao gồm bật/tắt isAvailable).
export class UpdateProductDto extends PartialType(CreateProductDto) {}
