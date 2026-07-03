import '../core/api_client.dart';
import '../models/user.dart';

class AuthService {
  final ApiClient client;

  AuthService(this.client);

  Future<void> register(String email, String password, String name) async {
    final data = await client.post(
      '/api/v1/auth/register',
      body: {'email': email, 'password': password, 'name': name},
      auth: false,
    );
    await client.setToken(data['access_token']);
  }

  Future<void> login(String email, String password) async {
    final data = await client.post(
      '/api/v1/auth/login',
      body:
          'username=${Uri.encodeComponent(email)}&password=${Uri.encodeComponent(password)}',
      auth: false,
      form: true,
    );
    await client.setToken(data['access_token']);
  }

  Future<AppUser> me() async {
    final data = await client.get('/api/v1/auth/me');
    return AppUser.fromJson(data);
  }

  Future<AppUser> updateProfile(Map<String, dynamic> fields) async {
    final data = await client.patch('/api/v1/users/me', body: fields);
    return AppUser.fromJson(data);
  }

  Future<void> logout() => client.clearToken();
}
