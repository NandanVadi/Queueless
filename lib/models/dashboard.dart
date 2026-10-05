class UserStatistics {
  final int total;
  final int operators;
  final int admins;

  UserStatistics({
    required this.total,
    required this.operators,
    required this.admins,
  });

  factory UserStatistics.fromJson(Map<String, dynamic> json) {
    return UserStatistics(
      total: json['total'] ?? 0,
      operators: json['operators'] ?? 0,
      admins: json['admins'] ?? 0,
    );
  }
}

class QueueStatistics {
  final int total;
  final int today;
  final int waiting;
  final int serving;
  final int completed;
  final int cancelled;
  final int todayCompleted;
  final int todayCancelled;

  QueueStatistics({
    required this.total,
    required this.today,
    required this.waiting,
    required this.serving,
    required this.completed,
    required this.cancelled,
    required this.todayCompleted,
    required this.todayCancelled,
  });

  factory QueueStatistics.fromJson(Map<String, dynamic> json) {
    return QueueStatistics(
      total: json['total'] ?? 0,
      today: json['today'] ?? 0,
      waiting: json['waiting'] ?? 0,
      serving: json['serving'] ?? 0,
      completed: json['completed'] ?? 0,
      cancelled: json['cancelled'] ?? 0,
      todayCompleted: json['todayCompleted'] ?? 0,
      todayCancelled: json['todayCancelled'] ?? 0,
    );
  }
}

class AppointmentStatistics {
  final int total;
  final int today;
  final int scheduled;
  final int completed;
  final int cancelled;

  AppointmentStatistics({
    required this.total,
    required this.today,
    required this.scheduled,
    required this.completed,
    required this.cancelled,
  });

  factory AppointmentStatistics.fromJson(Map<String, dynamic> json) {
    return AppointmentStatistics(
      total: json['total'] ?? 0,
      today: json['today'] ?? 0,
      scheduled: json['scheduled'] ?? 0,
      completed: json['completed'] ?? 0,
      cancelled: json['cancelled'] ?? 0,
    );
  }
}

class ServiceAnalytics {
  final int id;
  final String name;
  final bool isActive;
  final QueueStatistics queue;
  final AppointmentStatistics appointments;
  final int? currentServingToken;
  final int peopleWaiting;
  final int estimatedWaitTime;

  ServiceAnalytics({
    required this.id,
    required this.name,
    required this.isActive,
    required this.queue,
    required this.appointments,
    this.currentServingToken,
    required this.peopleWaiting,
    required this.estimatedWaitTime,
  });

  factory ServiceAnalytics.fromJson(Map<String, dynamic> json) {
    return ServiceAnalytics(
      id: json['id'],
      name: json['name'],
      isActive: json['isActive'] ?? true,
      queue: QueueStatistics.fromJson(json['queue'] ?? {}),
      appointments: AppointmentStatistics.fromJson(json['appointments'] ?? {}),
      currentServingToken: json['currentServingToken'],
      peopleWaiting: json['peopleWaiting'] ?? 0,
      estimatedWaitTime: json['estimatedWaitTime'] ?? 0,
    );
  }
}

class DashboardData {
  final UserStatistics users;
  final QueueStatistics queue;
  final AppointmentStatistics appointments;
  final List<ServiceAnalytics> services;

  DashboardData({
    required this.users,
    required this.queue,
    required this.appointments,
    required this.services,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      users: UserStatistics.fromJson(json['users'] ?? {}),
      queue: QueueStatistics.fromJson(json['queue'] ?? {}),
      appointments: AppointmentStatistics.fromJson(json['appointments'] ?? {}),
      services: (json['services'] as List<dynamic>?)
              ?.map((s) => ServiceAnalytics.fromJson(s))
              .toList() ??
          [],
    );
  }
}
