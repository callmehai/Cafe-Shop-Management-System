import { Controller } from '@nestjs/common';
import { InventoryService } from './inventory.service';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';

@Roles(Role.MANAGER, Role.ADMINISTRATOR)
@Controller('inventory')
export class InventoryController {
  constructor(private readonly inventory: InventoryService) {}
  // TODO routes: ingredients, purchase-orders, stock-in, low-stock
}
