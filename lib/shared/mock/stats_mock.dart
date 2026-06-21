class ChannelStat {
  final String name;
  final int percentage;
  final int color; // ARGB int

  const ChannelStat({required this.name, required this.percentage, required this.color});
}

class DailyRevenue {
  final String day;
  final double amount;
  const DailyRevenue({required this.day, required this.amount});
}

const mockRevenue = 1250000;
const mockConversations = 324;
const mockResponseRate = 92;
const mockRevenueGrowth = 18.5;
const mockConversationsGrowth = 12.3;
const mockResponseRateGrowth = 7.1;

const mockChannelStats = [
  ChannelStat(name: 'WhatsApp', percentage: 45, color: 0xFF22C55E),
  ChannelStat(name: 'SMS', percentage: 20, color: 0xFF3B82F6),
  ChannelStat(name: 'Email', percentage: 20, color: 0xFF8B5CF6),
  ChannelStat(name: 'Facebook', percentage: 10, color: 0xFFF59E0B),
  ChannelStat(name: 'Instagram', percentage: 5, color: 0xFFEC4899),
];

const mockDailyRevenue = [
  DailyRevenue(day: 'Lun', amount: 120000),
  DailyRevenue(day: 'Mar', amount: 185000),
  DailyRevenue(day: 'Mer', amount: 145000),
  DailyRevenue(day: 'Jeu', amount: 310000),
  DailyRevenue(day: 'Ven', amount: 275000),
  DailyRevenue(day: 'Sam', amount: 480000),
  DailyRevenue(day: 'Dim', amount: 380000),
];
