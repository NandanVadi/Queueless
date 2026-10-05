const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const services = [
    {
      id: 1,
      name: "Banking Services",
      description: "Account management, cash deposits, withdrawals, and counter services.",
      icon: "bank",
      isActive: true
    },
    {
      id: 2,
      name: "Document Services",
      description: "Apply for, renew, or collect official documents and certificates.",
      icon: "document",
      isActive: true
    },
    {
      id: 3,
      name: "General Consultation",
      description: "Speak with a representative for general inquiries and assistance.",
      icon: "consultation",
      isActive: true
    },
    {
      id: 4,
      name: "Salon & Beauty",
      description: "Book a haircut, styling, or beauty treatment session.",
      icon: "salon",
      isActive: true
    }
  ];

  for (const s of services) {
    // upsert ensures the seed is idempotent.
    // If a service with the given ID already exists, it updates it.
    // Otherwise, it creates it.
    await prisma.service.upsert({
      where: { id: s.id },
      update: {
        name: s.name,
        description: s.description,
        icon: s.icon,
        isActive: s.isActive
      },
      create: {
        id: s.id,
        name: s.name,
        description: s.description,
        icon: s.icon,
        isActive: s.isActive
      }
    });
  }

  console.log('Seeding completed.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
