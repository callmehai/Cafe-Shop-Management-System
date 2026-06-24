import { Module } from '@nestjs/common';
import { ProductsController } from './products.controller';
import { CategoriesController } from './categories.controller';
import { MenuService } from './menu.service';

@Module({ controllers: [ProductsController, CategoriesController], providers: [MenuService] })
export class MenuModule {}
