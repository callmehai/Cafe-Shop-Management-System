import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { MenuModule } from './menu/menu.module';
import { OrdersModule } from './orders/orders.module';
import { PaymentsModule } from './payments/payments.module';
import { InventoryModule } from './inventory/inventory.module';
import { CustomersModule } from './customers/customers.module';
import { TablesModule } from './tables/tables.module';
import { ReportsModule } from './reports/reports.module';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    UsersModule,
    MenuModule,
    OrdersModule,
    PaymentsModule,
    InventoryModule,
    CustomersModule,
    TablesModule,
    ReportsModule,
  ],
  providers: [
    // CR-06: mặc định mọi route yêu cầu đăng nhập (dùng @Public() để mở).
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    // CR-07: kiểm tra role theo @Roles().
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
})
export class AppModule {}
