import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post } from '@nestjs/common';
import { InventoryService } from './inventory.service';
import { CreateIngredientDto, UpdateIngredientDto } from './dto/ingredient.dto';
import { StockInDto } from './dto/stock-in.dto';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { AuditAction } from '../audit-log/audit.decorator';

@Roles(Role.MANAGER, Role.ADMINISTRATOR)
@Controller('inventory')
export class InventoryController {
  constructor(private readonly inventory: InventoryService) {}

  @Get('ingredients')
  ingredients() {
    return this.inventory.listIngredients();
  }

  @Get('low-stock')
  lowStock() {
    return this.inventory.lowStock();
  }

  @Post('ingredients')
  @AuditAction('CREATE_INGREDIENT')
  createIngredient(@Body() dto: CreateIngredientDto) {
    return this.inventory.createIngredient(dto);
  }

  @Patch('ingredients/:id')
  @AuditAction('UPDATE_INGREDIENT')
  updateIngredient(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateIngredientDto) {
    return this.inventory.updateIngredient(id, dto);
  }

  @Delete('ingredients/:id')
  @AuditAction('DELETE_INGREDIENT')
  deleteIngredient(@Param('id', ParseIntPipe) id: number) {
    return this.inventory.deleteIngredient(id);
  }

  @Get('purchase-orders')
  purchaseOrders() {
    return this.inventory.listPurchaseOrders();
  }

  // Goods receipt (Stock-In) — cộng kho (BR-12).
  @Post('stock-in')
  @AuditAction('STOCK_IN')
  receive(@Body() dto: StockInDto, @CurrentUser() user: AuthUser) {
    return this.inventory.receiveStock(dto, user.userId);
  }
}
