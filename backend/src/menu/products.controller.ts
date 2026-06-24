import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Query } from '@nestjs/common';
import { MenuService } from './menu.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';

@Controller('products')
export class ProductsController {
  constructor(private readonly menu: MenuService) {}

  // Đọc: mọi role đã đăng nhập (cashier tạo order cần xem). Không gắn @Roles.
  @Get()
  list(@Query('search') search?: string) {
    return this.menu.listProducts(search);
  }

  // Ghi: chỉ Manager/Admin (BR-05).
  @Roles(Role.MANAGER, Role.ADMINISTRATOR)
  @Post()
  create(@Body() dto: CreateProductDto) {
    return this.menu.createProduct(dto);
  }

  @Roles(Role.MANAGER, Role.ADMINISTRATOR)
  @Patch(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateProductDto) {
    return this.menu.updateProduct(id, dto);
  }

  @Roles(Role.MANAGER, Role.ADMINISTRATOR)
  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.menu.deleteProduct(id);
  }
}
