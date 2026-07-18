import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { AuditLogService } from './audit-log.service';
import { AUDIT_ACTION_KEY } from './audit.decorator';

@Injectable()
export class AuditLogInterceptor implements NestInterceptor {
  constructor(
    private readonly reflector: Reflector,
    private readonly auditService: AuditLogService,
  ) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const action = this.reflector.getAllAndOverride<string>(AUDIT_ACTION_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!action) {
      return next.handle();
    }

    const request = context.switchToHttp().getRequest();
    const user = request.user;
    const ipAddress = (request.headers['x-forwarded-for'] as string) || request.socket.remoteAddress || '127.0.0.1';

    return next.handle().pipe(
      tap({
        next: (data) => {
          const sanitizedBody = this.sanitizeBody(request.body);
          this.auditService.log({
            userId: user?.userId,
            username: user?.username,
            action,
            details: JSON.stringify({
              method: request.method,
              url: request.url,
              body: sanitizedBody,
              status: 'SUCCESS',
            }),
            ipAddress,
          });
        },
        error: (err) => {
          const sanitizedBody = this.sanitizeBody(request.body);
          this.auditService.log({
            userId: user?.userId,
            username: user?.username,
            action: `${action}_FAILED`,
            details: JSON.stringify({
              method: request.method,
              url: request.url,
              body: sanitizedBody,
              status: 'FAILED',
              errorMessage: err.message || err.toString(),
            }),
            ipAddress,
          });
        },
      }),
    );
  }

  private sanitizeBody(body: any): any {
    if (!body) return null;
    const copy = { ...body };
    const sensitiveFields = ['password', 'passwordHash', 'token', 'accessToken', 'secret'];
    for (const field of sensitiveFields) {
      if (field in copy) {
        copy[field] = '********';
      }
    }
    return copy;
  }
}
