-- CreateEnum
CREATE TYPE "PrepStatus" AS ENUM ('PENDING', 'MAKING', 'DONE');

-- AlterTable
ALTER TABLE "OrderItem" ADD COLUMN     "prepStatus" "PrepStatus" NOT NULL DEFAULT 'PENDING';
