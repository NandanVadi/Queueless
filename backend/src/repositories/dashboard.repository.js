const prisma = require('../lib/prisma');

class DashboardRepository {
  async getDashboardData() {
    const now = new Date();
    // Start of current UTC day
    const startOfToday = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
    const endOfToday = new Date(startOfToday.getTime() + 24 * 60 * 60 * 1000);

    const [
      users,
      queueTokens,
      appointments,
      services
    ] = await Promise.all([
      prisma.user.groupBy({
        by: ['role'],
        _count: true
      }),
      prisma.queueToken.findMany({
        select: {
          status: true,
          createdAt: true,
          isActive: true
        }
      }),
      prisma.appointment.findMany({
        select: {
          status: true,
          createdAt: true
        }
      }),
      prisma.service.findMany({
        include: {
          queueTokens: {
            select: {
              status: true,
              createdAt: true,
              isActive: true,
              tokenNumber: true
            }
          },
          appointments: {
            select: {
              status: true,
              createdAt: true
            }
          }
        }
      })
    ]);

    // Aggregate Users
    const userStats = { total: 0, operators: 0, admins: 0 };
    users.forEach(u => {
      userStats.total += u._count;
      if (u.role === 'operator') userStats.operators = u._count;
      if (u.role === 'admin') userStats.admins = u._count;
    });

    // Aggregate Queue
    const queueStats = {
      total: queueTokens.length,
      today: 0,
      waiting: 0,
      serving: 0,
      completed: 0,
      cancelled: 0,
      todayCompleted: 0,
      todayCancelled: 0
    };

    queueTokens.forEach(q => {
      const isToday = q.createdAt >= startOfToday && q.createdAt < endOfToday;
      if (isToday) queueStats.today++;

      if (q.status === 'waiting') queueStats.waiting++;
      else if (q.status === 'serving') queueStats.serving++;
      else if (q.status === 'completed') {
        queueStats.completed++;
        if (isToday) queueStats.todayCompleted++;
      }
      else if (q.status === 'cancelled') {
        queueStats.cancelled++;
        if (isToday) queueStats.todayCancelled++;
      }
    });

    // Aggregate Appointments
    const apptStats = {
      total: appointments.length,
      today: 0,
      scheduled: 0,
      completed: 0,
      cancelled: 0
    };

    appointments.forEach(a => {
      const isToday = a.createdAt >= startOfToday && a.createdAt < endOfToday;
      if (isToday) apptStats.today++;
      
      if (a.status === 'scheduled') apptStats.scheduled++;
      else if (a.status === 'completed') apptStats.completed++;
      else if (a.status === 'cancelled') apptStats.cancelled++;
    });

    // Aggregate Services
    const serviceStats = services.map(s => {
      let totalQ = s.queueTokens.length;
      let todayQ = 0;
      let waitQ = 0;
      let serveQ = 0;
      let compQ = 0;
      let cancQ = 0;

      let currentTokenNumber = null;
      let minServingToken = null;

      s.queueTokens.forEach(q => {
        const isToday = q.createdAt >= startOfToday && q.createdAt < endOfToday;
        if (isToday) todayQ++;

        if (q.status === 'waiting' && q.isActive) waitQ++;
        else if (q.status === 'serving' && q.isActive) {
          serveQ++;
          if (minServingToken === null || q.tokenNumber < minServingToken) {
            minServingToken = q.tokenNumber;
          }
        }
        else if (q.status === 'completed') compQ++;
        else if (q.status === 'cancelled') cancQ++;
      });
      
      currentTokenNumber = minServingToken;

      let totalA = s.appointments.length;
      let todayA = 0;
      let schedA = 0;
      let compA = 0;
      let cancA = 0;

      s.appointments.forEach(a => {
        const isToday = a.createdAt >= startOfToday && a.createdAt < endOfToday;
        if (isToday) todayA++;
        if (a.status === 'scheduled') schedA++;
        else if (a.status === 'completed') compA++;
        else if (a.status === 'cancelled') cancA++;
      });

      return {
        id: s.id,
        name: s.name,
        isActive: s.isActive,
        queue: {
          total: totalQ,
          today: todayQ,
          waiting: waitQ,
          serving: serveQ,
          completed: compQ,
          cancelled: cancQ
        },
        appointments: {
          total: totalA,
          today: todayA,
          scheduled: schedA,
          completed: compA,
          cancelled: cancA
        },
        currentServingToken: currentTokenNumber,
        peopleWaiting: waitQ,
        estimatedWaitTime: waitQ * 10
      };
    });

    return {
      users: userStats,
      queue: queueStats,
      appointments: apptStats,
      services: serviceStats
    };
  }
}

module.exports = new DashboardRepository();
