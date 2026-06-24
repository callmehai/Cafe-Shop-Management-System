import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post } from '@nestjs/common';
import { MenuService } from './menu.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';

@Controller('categories')
export class CategoriesController {
  constructor(private readonly menu: MenuService) {}

  @Get()
  list() {
    return this.menu.listCategories();
  }

  @Roles(Role.MANAGER, Role.ADMINISTRATOR)
  @Post()
  create(@Body() dto: CreateCategoryDto) {
    return this.menu.createCategory(dto);
  }

  @Roles(Role.MANAGER, Role.ADMINISTRATOR)
  @Patch(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateCategoryDto) {
    return this.menu.updateCategory(id, dto);
  }

  @Roles(Role.MANAGER, Role.ADMINISTRATOR)
  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.menu.deleteCategory(id);
  }
}
