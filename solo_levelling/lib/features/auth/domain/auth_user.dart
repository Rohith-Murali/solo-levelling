import '../../../core/network/api_client.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.hasCharacter = false,
  });

  final String id;
  final String email;
  final bool hasCharacter;

  AuthUser copyWith({bool? hasCharacter}) {
    return AuthUser(
      id: id,
      email: email,
      hasCharacter: hasCharacter ?? this.hasCharacter,
    );
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    final hasCharacter = json['hasCharacter'];
    if (id is! String || email is! String || hasCharacter is! bool) {
      throw const ApiException('The server returned an invalid user.');
    }

    return AuthUser(id: id, email: email, hasCharacter: hasCharacter);
  }
}
