# QueueLess Backend API (Milestone 10)

This directory contains the Node.js + Express backend for the QueueLess application, now powered by PostgreSQL and Prisma ORM.

## Tech Stack
- **Framework**: Node.js + Express
- **Database**: PostgreSQL (Chosen for robust ACID transactions and strict relational data integrity required by queue/appointment systems).
- **ORM**: Prisma (Chosen for intuitive schemas, seamless migrations, and excellent type-safety).

## Prisma Integration & Database Setup

1. **Environment Setup**:
   Copy `.env.example` to `.env` and fill in your local PostgreSQL credentials:
   ```bash
   cp .env.example .env
   ```

2. **Database Migrations**:
   We use Prisma to track schema changes. To apply the initial migration and create the tables:
   ```bash
   npx prisma migrate dev --name init
   ```

3. **Seeding the Database**:
   We provide a safe, idempotent seeding script that populates the default service catalog (Banking, Consultation, etc.).
   ```bash
   npm run prisma seed
   ```

## Architecture
The backend now enforces a clean separation of concerns:
- **Routes (`src/routes/`)**: Map HTTP verbs to Controller functions.
- **Controllers (`src/controllers/`)**: Handle HTTP request/response lifecycles and error formatting.
- **Services (`src/services/`)**: Encapsulate the core business logic.
- **Repositories (`src/repositories/`)**: Abstract database queries utilizing the Prisma Client singleton (`src/lib/prisma.js`).

## SQLite Caching Note (Flutter Compatibility)
The Flutter mobile application still retains its local SQLite database. 
**Why?**
The Flutter app uses a **Repository Pattern** (`ServiceRepository`) to query this backend. If the backend is unreachable (offline/network drop), the app seamlessly falls back to reading the last known catalog from SQLite. The IDs sent by PostgreSQL are strictly maintained in SQLite to preserve existing queue/appointment relationships locally.

## Testing
To run the automated API tests (which use `jest-mock-extended` to mock the Prisma database client without requiring a real database):
```bash
npm test
```
