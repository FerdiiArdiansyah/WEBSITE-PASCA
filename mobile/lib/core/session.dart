import 'package:flutter/foundation.dart';

import 'api.dart';

class User {
  final int id;
  final String username, nama, role, email;
  final String? telepon, foto;
  User(this.id, this.username, this.nama, this.role, this.email, this.telepon, this.foto);
  factory User.fromJson(Map j) => User(j['id'], j['username'], j['nama'], j['role'], j['email'] ?? '', j['telepon'], j['foto']);
  String get inisial => nama.isEmpty ? '?' : nama.trim()[0].toUpperCase();
  String get namaDepan => nama.split(' ').first;
}

/// Status sesi login (role-based) untuk seluruh aplikasi.
class Session extends ChangeNotifier {
  Session._();
  static final Session I = Session._();

  User? user;
  bool loading = true;

  Future<void> restore() async {
    await Api.I.init();
    if (Api.I.token != null) {
      try {
        user = User.fromJson(await Api.I.get('/api/auth/auth/me'));
      } catch (_) {
        await Api.I.setToken(null);
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final r = await Api.I.post('/api/auth/auth/login', body: {'username': username, 'password': password});
    await Api.I.setToken(r['access_token']);
    user = User.fromJson(r['user']);
    notifyListeners();
  }

  Future<void> refreshUser() async {
    user = User.fromJson(await Api.I.get('/api/auth/auth/me'));
    notifyListeners();
  }

  Future<void> logout() async {
    await Api.I.setToken(null);
    user = null;
    notifyListeners();
  }
}
