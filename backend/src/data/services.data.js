// Mock data for Milestone 8 (Development persistence)
// In later milestones, this will be replaced by a real server database.
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

module.exports = {
  getServices: () => services
};
