import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
import * as fs from 'fs';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  app.setGlobalPrefix('api');

  // Ensure uploads directory exists
  const uploadsDir = join(process.cwd(), 'uploads');
  console.log('Serving static files from:', uploadsDir);
  if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
  }
  const defaultUploadsDir = join(uploadsDir, 'default');
  if (!fs.existsSync(defaultUploadsDir)) {
    fs.mkdirSync(defaultUploadsDir, { recursive: true });
  }

  // Serve static assets from the uploads directory under /uploads prefix
  app.useStaticAssets(uploadsDir, {
    prefix: '/uploads',
    setHeaders: (res) => {
      res.set('Access-Control-Allow-Origin', '*');
      res.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      res.set('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
    },
  });

  // CR-08/CR-15: validate + trim input trước khi xử lý
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }),
  );
  app.enableCors();
  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
