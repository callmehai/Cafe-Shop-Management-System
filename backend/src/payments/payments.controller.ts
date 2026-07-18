import { Body, Controller, Post, Get, Param, Query, Req, ParseIntPipe, Header } from '@nestjs/common';
import { Request } from 'express';
import { PaymentsService } from './payments.service';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';

@Roles(Role.CASHIER, Role.MANAGER, Role.ADMINISTRATOR)
@Controller('payments')
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  @Post()
  process(@Body() dto: CreatePaymentDto, @CurrentUser() user: AuthUser) {
    return this.payments.process(dto, user.userId);
  }

  @Post(':id/vnpay-url')
  async getVnPayUrl(
    @Param('id', ParseIntPipe) id: number,
    @Req() req: Request
  ) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress || '127.0.0.1';
    const url = await this.payments.getVnPayUrl(id, ipAddress);
    return { url };
  }

  @Public()
  @Header('Content-Type', 'text/html')
  @Get('vnpay-return')
  async vnPayReturn(@Query() query: any) {
    const ipnResult = await this.payments.handleVnPayIpn(query);
    const isSuccess = query['vnp_ResponseCode'] === '00' && (ipnResult.RspCode === '00' || ipnResult.RspCode === '02');
    const orderNo = query['vnp_TxnRef'] || '';
    return `
      <html>
        <head>
          <title>Payment Result</title>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background-color: #f7f9fa; }
            .card { background: white; padding: 32px; border-radius: 16px; box-shadow: 0 4px 12px rgba(0,0,0,0.08); text-align: center; max-width: 380px; width: 100%; }
            h1 { color: ${isSuccess ? '#2e7d32' : '#c62828'}; margin-top: 0; font-size: 22px; }
            p { color: #555; font-size: 15px; line-height: 1.5; }
            .btn { display: inline-block; background: #E07A5F; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: bold; margin-top: 20px; font-size: 14px; }
          </style>
        </head>
        <body>
          <div class="card">
            <h1>${isSuccess ? 'Thanh Toán Thành Công!' : 'Thanh Toán Thất Bại'}</h1>
            <p>Đơn hàng: <strong>${orderNo}</strong></p>
            <p>${isSuccess ? 'Giao dịch đã được xác nhận và đang xử lý.' : 'Đã xảy ra lỗi trong quá trình thanh toán hoặc người dùng hủy giao dịch.'}</p>
            <a href="#" class="btn" onclick="window.close(); return false;">Đóng cửa sổ</a>
          </div>
        </body>
      </html>
    `;
  }

  @Public()
  @Get('vnpay-ipn')
  vnPayIpn(@Query() query: any) {
    return this.payments.handleVnPayIpn(query);
  }
}
