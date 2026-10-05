const dashboardRepository = require('../repositories/dashboard.repository');

class DashboardService {
  async getDashboardData() {
    return dashboardRepository.getDashboardData();
  }
}

module.exports = new DashboardService();
