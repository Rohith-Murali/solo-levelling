import '../../../core/network/api_client.dart';
import '../domain/dashboard_data.dart';

class DashboardApi {
  const DashboardApi(this._client);

  final ApiClient _client;

  Future<DashboardData> getDashboard(String accessToken) async {
    final response = await _client.getJson(
      'dashboard',
      bearerToken: accessToken,
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('The server returned invalid dashboard data.');
    }
    return DashboardData.fromJson(data);
  }
}
