import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'public_screen.dart';

/// Tampilkan tombol akun demo di layar login (matikan untuk produksi).
const bool kDemoMode = true;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _u = TextEditingController(), _p = TextEditingController();
  bool _busy = false, _show = false;

  Future<void> _login() async {
    if (_u.text.isEmpty || _p.text.isEmpty) return;
    setState(() => _busy = true);
    await runAction(context, () => Session.I.login(_u.text.trim(), _p.text));
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _server() async {
    final v = await inputDialog(context, 'Alamat Server API', label: 'contoh: http://192.168.1.10:8000', awal: Api.I.baseUrl, maxLines: 1);
    if (v != null && v.isNotEmpty) {
      await Api.I.setBaseUrl(v);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Server: ${Api.I.baseUrl}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradNavy),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 84, height: 84,
                    decoration: BoxDecoration(gradient: AppColors.gradGold, borderRadius: BorderRadius.circular(26),
                        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .4), blurRadius: 24, offset: const Offset(0, 10))]),
                    child: const Icon(Icons.school_rounded, color: AppColors.navy, size: 46),
                  ),
                  const SizedBox(height: 18),
                  const Text('SIAKAD Pascasarjana', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Universitas Muhammadiyah Makassar', style: TextStyle(color: Colors.white.withValues(alpha: .75), fontSize: 13)),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 40, offset: const Offset(0, 20))]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Text('Masuk ke Portal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const Text('Gunakan akun yang diberikan bagian akademik.', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                      const SizedBox(height: 18),
                      TextField(controller: _u, textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Username / NIM / NIDN', prefixIcon: Icon(Icons.person_outline_rounded))),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _p, obscureText: !_show, onSubmitted: (_) => _login(),
                        decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _show = !_show))),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _busy ? null : _login,
                        icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login_rounded),
                        label: Text(_busy ? 'Memproses...' : 'Masuk'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PublicScreen())),
                        icon: const Icon(Icons.public_rounded), label: const Text('Informasi & Pendaftaran'),
                      ),
                      if (kDemoMode) ...[
                        const SizedBox(height: 16),
                        const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Akun demo', style: TextStyle(fontSize: 11, color: AppColors.muted))), Expanded(child: Divider())]),
                        const SizedBox(height: 8),
                        Row(children: [
                          for (final d in [('Mahasiswa', '25MKM001', 'mhs123', Icons.school_outlined), ('Dosen', '0003037003', 'dosen123', Icons.co_present_outlined), ('Admin', 'admin', 'admin123', Icons.admin_panel_settings_outlined)])
                            Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: OutlinedButton(
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: EdgeInsets.zero, side: const BorderSide(color: Color(0xFFE3E6F0))),
                              onPressed: _busy ? null : () { _u.text = d.$2; _p.text = d.$3; _login(); },
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(d.$4, size: 16), Text(d.$1, style: const TextStyle(fontSize: 10.5))]),
                            ))),
                        ]),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 18),
                  TextButton.icon(
                    onPressed: _server,
                    icon: Icon(Icons.dns_outlined, size: 16, color: Colors.white.withValues(alpha: .7)),
                    label: Text(Api.I.baseUrl, style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 12)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Layar pembuka saat sesi dipulihkan.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.gradNavy),
          child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.school_rounded, color: AppColors.gold, size: 72),
            SizedBox(height: 16),
            Text('SIAKAD Pascasarjana', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            SizedBox(height: 24),
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 3)),
          ])),
        ),
      );
}

/// Pengaturan akun & server (dipakai semua peran).
class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  Future<void> _gantiPassword(BuildContext context) async {
    final lama = TextEditingController(), baru = TextEditingController(), konf = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ganti Password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: lama, obscureText: true, decoration: const InputDecoration(labelText: 'Password lama')),
          const SizedBox(height: 10),
          TextField(controller: baru, obscureText: true, decoration: const InputDecoration(labelText: 'Password baru (min. 8)')),
          const SizedBox(height: 10),
          TextField(controller: konf, obscureText: true, decoration: const InputDecoration(labelText: 'Konfirmasi')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('Simpan'))],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (baru.text != konf.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konfirmasi password tidak cocok')));
      return;
    }
    await runAction(context, () => Api.I.put('/api/auth/auth/me/password', body: {'password_lama': lama.text, 'password_baru': baru.text}), sukses: 'Password berhasil diganti');
  }

  Future<void> _editProfil(BuildContext context) async {
    final u = Session.I.user!;
    final nama = TextEditingController(text: u.nama), email = TextEditingController(text: u.email), telp = TextEditingController(text: u.telepon);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ubah Profil'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nama, decoration: const InputDecoration(labelText: 'Nama lengkap')),
          const SizedBox(height: 10),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 10),
          TextField(controller: telp, decoration: const InputDecoration(labelText: 'Telepon')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('Simpan'))],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runAction(context, () async {
      await Api.I.put('/api/auth/auth/me', body: {'nama': nama.text, 'email': email.text, 'telepon': telp.text});
      await Session.I.refreshUser();
    }, sukses: 'Profil diperbarui');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final u = Session.I.user!;
        return Scaffold(
          appBar: AppBar(title: const Text('Profil & Pengaturan')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: AppColors.gradPrimary, borderRadius: BorderRadius.circular(22)),
              child: Row(children: [
                Avatar(u.inisial, size: 64),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.nama, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('${cap(u.role)} · ${u.username}', style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 12.5)),
                  Text(u.email, style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 12.5)),
                ])),
              ]),
            ),
            const SizedBox(height: 16),
            Card(child: Column(children: [
              ListTile(leading: const IconBox(Icons.edit_outlined), title: const Text('Ubah Profil'), subtitle: const Text('Nama, email, telepon'), trailing: const Icon(Icons.chevron_right), onTap: () => _editProfil(context)),
              const Divider(height: 1),
              ListTile(leading: const IconBox(Icons.key_rounded, color: AppColors.warning), title: const Text('Ganti Password'), trailing: const Icon(Icons.chevron_right), onTap: () => _gantiPassword(context)),
              const Divider(height: 1),
              ListTile(
                leading: const IconBox(Icons.dns_outlined, color: AppColors.info), title: const Text('Server API'), subtitle: Text(Api.I.baseUrl), trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final v = await inputDialog(context, 'Alamat Server API', label: 'URL', awal: Api.I.baseUrl, maxLines: 1);
                  if (v != null && v.isNotEmpty) await Api.I.setBaseUrl(v);
                },
              ),
            ])),
            const SizedBox(height: 16),
            Card(child: ListTile(
              leading: const IconBox(Icons.logout_rounded, color: AppColors.danger), title: const Text('Keluar', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
              onTap: () async {
                if (await konfirmasi(context, 'Keluar', 'Anda yakin ingin keluar dari aplikasi?', ya: 'Keluar', bahaya: true)) {
                  await Session.I.logout();
                  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                }
              },
            )),
            const SizedBox(height: 24),
            const Center(child: Text('SIAKAD Pascasarjana v1.0.0\nUniversitas Muhammadiyah Makassar', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 11.5))),
          ]),
        );
      },
    );
  }
}

/// Daftar notifikasi pengguna.
class NotifikasiScreen extends StatelessWidget {
  const NotifikasiScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notifikasi'), actions: [
          TextButton(onPressed: () => runAction(context, () => Api.I.post('/api/notifikasi/baca-semua'), sukses: 'Semua ditandai dibaca'), child: const Text('Tandai dibaca')),
        ]),
        body: AsyncView<List>(
          load: () async => (await Api.I.get('/api/notifikasi')) as List,
          builder: (c, data, reload) => data.isEmpty
              ? ListView(children: const [EmptyState('Belum ada notifikasi.', icon: Icons.notifications_none_rounded)])
              : ListView.separated(
                  padding: const EdgeInsets.all(16), itemCount: data.length, separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (c, i) {
                    final n = data[i];
                    return Card(
                      color: n['dibaca'] ? Colors.white : AppColors.primary.withValues(alpha: .06),
                      child: ListTile(
                        leading: IconBox(n['dibaca'] ? Icons.notifications_none_rounded : Icons.notifications_active_rounded, color: n['dibaca'] ? AppColors.muted : AppColors.primary),
                        title: Text(n['judul'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        subtitle: Text('${n['isi'] ?? ''}\n${tanggal(n['created_at'], withTime: true)}', style: const TextStyle(fontSize: 12)),
                        isThreeLine: true,
                        onTap: () async {
                          await Api.I.patch('/api/notifikasi/${n['id']}/baca');
                          reload();
                        },
                      ),
                    );
                  },
                ),
        ),
      );
}
