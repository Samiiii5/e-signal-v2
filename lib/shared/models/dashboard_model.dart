class DashboardData {
  final String orgId;
  final String period;
  final String currency;
  final List<Map<String, dynamic>> kpis;
  final List<Map<String, dynamic>> signals;
  final Map<String, dynamic> revenueSeries;
  final List<Map<String, dynamic>> channelSplit;
  final List<Map<String, dynamic>> campaigns;
  final List<Map<String, dynamic>> activity;
  final List<Map<String, dynamic>> tasks;

  const DashboardData({
    required this.orgId,
    required this.period,
    required this.currency,
    required this.kpis,
    required this.signals,
    required this.revenueSeries,
    required this.channelSplit,
    required this.campaigns,
    required this.activity,
    required this.tasks,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      orgId: (json['org_id'] ?? '').toString(),
      period: (json['period'] ?? '').toString(),
      currency: (json['currency'] ?? 'XOF').toString(),
      kpis: _toMapList(json['kpis']),
      signals: _toMapList(json['signals']),
      revenueSeries: json['revenue_series'] is Map
          ? Map<String, dynamic>.from(json['revenue_series'] as Map)
          : {},
      channelSplit: _toMapList(json['channel_split']),
      campaigns: _toMapList(json['campaigns']),
      activity: _toMapList(json['activity']),
      tasks: _toMapList(json['tasks']),
    );
  }

  static List<Map<String, dynamic>> _toMapList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
