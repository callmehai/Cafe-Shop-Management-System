import { Controller, Get, Query } from '@nestjs/common';
import { MenuService } from './menu.service';
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

  // TODO: @Post/@Patch/@Delete với @Roles(Role.MANAGER, Role.ADMINISTRATOR) — BR-05
}
