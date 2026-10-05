# Contribution Plan: QueueLess - Smart Queue & Appointment System

This document outlines the division of work and feature ownership between the two team members for the QueueLess project.

## Nandan Vadi's Contributions (approx. 50%)
**Email:** nandanvadi@gmail.com
**GitHub:** NandanVadi

### Feature / Domain Ownership
1. **Authentication:** 
   - Complete login and registration workflows.
   - Profile management and password changing functionalities.
   - Backend auth controllers, services, repositories, and routes.
   - JWT middleware and verification.
2. **Appointments System:**
   - Appointment booking and forms.
   - Managing and viewing appointments (screens and widgets).
   - Backend appointment logic, controllers, and services.
3. **Admin & Operator Dashboards:**
   - Admin oversight interfaces and operator handling.
   - Dashboard statistics and backend dashboard routes.
   - Admin/Operator authorization middleware.

### Infrastructure & Integration
- API Configuration (`api_config.dart`)
- Socket real-time service (`socket_service.dart`)
- Database Helper logic (`database_helper.dart`)

## Darsh Parekh's Contributions (approx. 50%)
**Email:** parekhdarsh002@gmail.com
**GitHub:** DarshParekh205

### Feature / Domain Ownership
1. **Queue Management:**
   - Core queue tracking and "My Queue" interface.
   - Queue token models, cards, and intelligence logic.
   - Backend queue services, controllers, and repositories.
2. **QR System:**
   - QR code generation for tokens and scanning functionality.
   - Payload management and verification.
3. **Services Management:**
   - Defining and retrieving active services (service models, cards, forms).
   - Backend service routes and controllers.

### Infrastructure & Integration
- Core API Service integration (`api_service.dart`)
- Notification Service (`notification_service.dart`)
- Application theming and UI constants (`app_theme.dart`, `app_colors.dart`)

## Workload Assessment
The project is structurally balanced between the two team members. Both developers implemented components across the full stack (Flutter UI, Flutter repositories/services, Node.js controllers, backend services, database schema interaction, and tests). 

- **Nandan Vadi:** Focused on user identity, appointment scheduling, and the administrative backbone.
- **Darsh Parekh:** Focused on the core queuing engine, QR verification mechanisms, and service definitions.

