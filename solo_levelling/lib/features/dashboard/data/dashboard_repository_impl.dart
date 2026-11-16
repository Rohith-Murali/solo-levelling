import '../domain/dashboard_data.dart';
import '../domain/dashboard_repository.dart';
import 'dashboard_api.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl({required this.api});

  final DashboardApi api;

  @override
  Future<DashboardData> load(String accessToken) {
    return api.getDashboard(accessToken);
  }
}
