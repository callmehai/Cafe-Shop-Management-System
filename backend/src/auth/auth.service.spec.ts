import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { PrismaService } from '../prisma/prisma.service';
import { JwtService } from '@nestjs/jwt';
import { AuditLogService } from '../audit-log/audit-log.service';
import { UnauthorizedException, ForbiddenException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';

describe('AuthService', () => {
  let service: AuthService;
  let prisma: PrismaService;
  let jwt: JwtService;
  let audit: AuditLogService;

  const mockPrisma = {
    user: {
      findUnique: jest.fn(),
      update: jest.fn(),
    },
  };

  const mockJwt = {
    signAsync: jest.fn(),
  };

  const mockAudit = {
    log: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: JwtService, useValue: mockJwt },
        { provide: AuditLogService, useValue: mockAudit },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
    prisma = module.get<PrismaService>(PrismaService);
    jwt = module.get<JwtService>(JwtService);
    audit = module.get<AuditLogService>(AuditLogService);

    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('login', () => {
    it('should throw UnauthorizedException if user not found', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);

      await expect(service.login({ username: 'unknown', password: 'password' }, '127.0.0.1')).rejects.toThrow(
        UnauthorizedException,
      );

      expect(audit.log).toHaveBeenCalledWith(
        expect.objectContaining({
          username: 'unknown',
          action: 'LOGIN_FAILED',
        }),
      );
    });

    it('should throw ForbiddenException if account is locked', async () => {
      const lockedUntil = new Date(Date.now() + 5 * 60 * 1000);
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 1,
        username: 'cashier',
        isActive: true,
        lockedUntil,
      });

      await expect(service.login({ username: 'cashier', password: 'password' }, '127.0.0.1')).rejects.toThrow(
        ForbiddenException,
      );

      expect(audit.log).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 1,
          action: 'LOGIN_LOCKED',
        }),
      );
    });

    it('should successfully log in and reset attempts', async () => {
      const hashedPassword = await bcrypt.hash('password', 10);
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 1,
        username: 'cashier',
        fullName: 'Cashier Name',
        role: 'CASHIER',
        isActive: true,
        passwordHash: hashedPassword,
        failedAttempts: 2,
        lockedUntil: null,
      });
      mockJwt.signAsync.mockResolvedValue('fake-jwt-token');

      const result = await service.login({ username: 'cashier', password: 'password' }, '127.0.0.1');

      expect(result.accessToken).toBe('fake-jwt-token');
      expect(result.user.username).toBe('cashier');
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 1 },
        data: { failedAttempts: 0, lockedUntil: null },
      });
      expect(audit.log).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 1,
          action: 'LOGIN_SUCCESS',
        }),
      );
    });

    it('should increment failed attempts and lock account on 5th failure', async () => {
      const hashedPassword = await bcrypt.hash('password', 10);
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 1,
        username: 'cashier',
        passwordHash: hashedPassword,
        failedAttempts: 4,
        lockedUntil: null,
        isActive: true,
      });

      await expect(service.login({ username: 'cashier', password: 'wrong-password' }, '127.0.0.1')).rejects.toThrow(
        ForbiddenException,
      );

      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 1 },
        data: expect.objectContaining({
          failedAttempts: 5,
          lockedUntil: expect.any(Date),
        }),
      });

      expect(audit.log).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 1,
          action: 'LOGIN_LOCKED',
        }),
      );
    });
  });
});
