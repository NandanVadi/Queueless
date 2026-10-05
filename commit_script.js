const { execSync } = require('child_process');
const fs = require('fs');

function run(cmd) {
  console.log(`Running: ${cmd}`);
  try {
    execSync(cmd, { stdio: 'inherit' });
  } catch (e) {
    console.error(`Failed: ${cmd}`);
  }
}

// 1. Initial Project Setup
run('git add pubspec.yaml pubspec.lock analysis_options.yaml .gitignore README.md walkthrough.md backend/package.json backend/package-lock.json backend/prisma/ backend/README.md CONTRIBUTION_PLAN.md scratch_analyze.js backend/jest.config.js');
run('git add lib/main.dart lib/utils/api_config.dart lib/services/socket_service.dart lib/database/database_helper.dart');
run('git add lib/services/api_service.dart lib/services/notification_service.dart lib/utils/app_theme.dart lib/utils/app_colors.dart lib/utils/icon_helper.dart lib/widgets/empty_state.dart');
run('git add backend/src/lib/ backend/src/middleware/ backend/src/server.js backend/src/socket.js');
run('git add test/widget_test.dart test/database_test.dart test/api_service_test.dart test/notification_service_test.dart test/home_screen_test.dart test/sync_consistency_test.dart backend/spoof_test.js backend/test_api.js backend/test_integration.js backend/test_operator.js backend/verify_api.js');
run('git add android/ ios/ macos/ linux/ web/ windows/ .metadata');
run('git add lib/screens/home_screen.dart lib/screens/main_screen.dart lib/screens/splash_screen.dart');
run('git commit -m "chore: initial project setup and infrastructure"');

// 2. Nandan - Auth
run('git add lib/models/user.dart lib/repositories/auth_repository.dart lib/screens/login_screen.dart lib/screens/register_screen.dart lib/screens/profile_screen.dart lib/screens/change_password_screen.dart');
run('git add backend/src/controllers/auth.controller.js backend/src/repositories/auth.repository.js backend/src/services/auth.service.js backend/src/routes/auth.routes.js');
run('git add test/profile_screen_test.dart');
run('git commit -m "feat(auth): implement authentication flow"');

// 3. Nandan - Appointments
run('git add lib/models/appointment.dart lib/repositories/appointment_repository.dart lib/screens/appointment_form_screen.dart lib/screens/appointments_screen.dart lib/widgets/appointment_card.dart');
run('git add backend/src/controllers/appointment.controller.js backend/src/repositories/appointment.repository.js backend/src/services/appointment.service.js backend/src/routes/appointment.routes.js');
run('git add test/appointments_test.dart');
run('git commit -m "feat(appointments): implement appointment workflow"');

// 4. Nandan - Admin/Operator
run('git add lib/models/dashboard.dart lib/screens/admin_screen.dart lib/screens/admin_dashboard_screen.dart lib/screens/operator_screen.dart');
run('git add backend/src/controllers/dashboard.controller.js backend/src/repositories/dashboard.repository.js backend/src/services/dashboard.service.js backend/src/routes/admin_dashboard.routes.js backend/src/routes/operator.routes.js backend/src/routes/admin_services.routes.js');
run('git add test/admin_dashboard_screen_test.dart test/admin_dashboard_test.dart');
run('git commit -m "feat(admin): implement admin dashboard and operator workflow"');

// 5. Darsh - Queue
run('git add lib/models/queue_token.dart lib/repositories/queue_repository.dart lib/screens/my_queue_screen.dart lib/widgets/queue_token_card.dart');
run('git add backend/src/controllers/queue.controller.js backend/src/repositories/queue.repository.js backend/src/services/queue.service.js backend/src/routes/queue.routes.js');
run('git add test/my_queue_test.dart test/queue_intelligence_test.dart test/queue_repository_test.dart');
const darshCoAuthor = '\\n\\nCo-authored-by: Darsh Parekh <parekhdarsh002@gmail.com>';
run(`git commit -m "feat(queue): implement queue token management${darshCoAuthor}"`);

// 6. Darsh - QR
run('git add lib/utils/qr_payload.dart lib/screens/qr_display_screen.dart lib/screens/qr_scanner_screen.dart');
run('git add test/qr_payload_test.dart test/qr_verification_test.dart');
run(`git commit -m "feat(qr): implement QR generation and verification${darshCoAuthor}"`);

// 7. Darsh - Services
run('git add lib/models/service.dart lib/repositories/service_repository.dart lib/screens/service_detail_screen.dart lib/widgets/service_card.dart lib/widgets/service_form.dart');
run('git add backend/src/controllers/services.controller.js backend/src/repositories/service.repository.js backend/src/services/service.service.js backend/src/routes/services.routes.js');
run('git add test/service_repository_test.dart');
run(`git commit -m "feat(services): implement service models and logic${darshCoAuthor}"`);

// Add any remaining files that were missed
run('git add .');
run(`git commit -m "chore: include remaining project files${darshCoAuthor}"`);
