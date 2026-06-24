import { Controller, Get } from '@nestjs/common';
import { MenuService } from './menu.service';

@Controller('categories')
export class CategoriesController {
  constructor(private readonly menu: MenuService) {}

  @Get()
  list() {
    return this.menu.listCategories();
  }
  // TODO: CRUD Category — @Roles(Role.MANAGER, Role.ADMINISTRATOR)
}
