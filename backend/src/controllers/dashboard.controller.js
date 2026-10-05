const dashboardService = require('../services/dashboard.service');

const getDashboard = async (req, res) => {
  try {
    const dashboard = await dashboardService.getDashboardData();
    res.status(200).json({ dashboard });
  } catch (error) {
    console.error('Error fetching dashboard:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

module.exports = {
  getDashboard
};
