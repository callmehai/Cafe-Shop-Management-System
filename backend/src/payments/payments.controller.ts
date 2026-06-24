import { Body, Controller, Post } from '@nestjs/common';
import { PaymentsService } from './payments.service';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';

@Roles(Role.CASHIER, Role.MANAGER, Role.ADMINISTRATOR)
@Controller('payments')
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  @Post()
  process(@Body() dto: CreatePaymentDto, @CurrentUser() user: AuthUser) {
    return this.payments.process(dto, user.userId);
  }
}
