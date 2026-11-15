import '../../../core/network/api_client.dart';

class AuthUser {
  const AuthUser({required this.id, required this.email});

  final String id;
  final String email;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    if (id is! String || email is! String) {
      throw const ApiException('The server returned an invalid user.');
    }

    return AuthUser(id: id, email: email);
  }
}
