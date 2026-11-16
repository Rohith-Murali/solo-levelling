import 'dashboard_data.dart';

abstract interface class DashboardRepository {
  Future<DashboardData> load(String accessToken);
}
