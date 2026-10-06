import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/surat_dokumen.dart';
import '../widgets/ui.dart';
import 'auth_screens.dart';
import 'mahasiswa_screens.dart';
import 'public_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [const AdmDashboard(), const AdmAkademikMenu(), const AdmKeuangan(), const AdmLayananMenu(), const ProfilScreen()];
    return Scaffold(
      body: IndexedStack(index: _i, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i, onDestinationSelected: (i) => setState(() => _i = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school_rounded), label: 'Akademik'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments_rounded), label: 'Keuangan'),
          NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent_rounded), label: 'Layanan'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}

const _palette = [AppColors.primary, AppColors.gold, AppColors.sky, AppColors.danger, Color(0xFF14B8A6), Color(0xFF8B5CF6), AppColors.success, Color(0xFFF97316)];

// =============================================================== DASHBOARD
class AdmDashboard extends StatelessWidget {
  const AdmDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    final u = Session.I.user!;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [Avatar(u.inisial, size: 34), const SizedBox(width: 10), const Expanded(child: Text('Dashboard Admin'))]),
        actions: [IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotifikasiScreen())))],
      ),
      body: AsyncView<Map>(
        load: () async => (await Api.I.get('/api/dashboard/admin')) as Map,
        builder: (c, d, _) {
          final ak = d['akademik'] ?? {}, ta = ak['tahun_akademik'];
          final tesis = (d['tesis_per_status'] ?? {}) as Map, keu = (d['keuangan_per_status'] ?? {}) as Map, lay = d['layanan'] ?? {};
          final perProdi = (ak['mahasiswa_per_prodi'] ?? []) as List, perAngkatan = (ak['mahasiswa_per_angkatan'] ?? []) as List;
          final tugas = [
            ('KRS menunggu verifikasi', ak['krs_menunggu'] ?? 0, Icons.playlist_add_check_rounded, const AdmKrs()),
            ('Pembayaran menunggu verifikasi', d['bayar_menunggu'] ?? 0, Icons.payments_rounded, const AdmKeuangan(statusAwal: 'menunggu verifikasi')),
            ('Surat menunggu peninjauan', lay['surat_pending'] ?? 0, Icons.mail_rounded, const AdmSurat()),
            ('Pendaftar PMB baru', lay['pendaftar_baru'] ?? 0, Icons.person_add_rounded, const AdmPmb()),
            ('Pengajuan judul tesis', tesis['pengajuan'] ?? 0, Icons.auto_stories_rounded, const AdmTesis(statusAwal: 'pengajuan')),
          ];
          return ListView(padding: const EdgeInsets.all(16), children: [
            WelcomeBanner(
              title: 'Dashboard Staf / Admin', subtitle: 'Pantau akademik, keuangan, dan layanan dalam satu tempat.', icon: Icons.admin_panel_settings_rounded,
              pills: [(Icons.calendar_month_outlined, 'TA ${ta?['nama'] ?? '-'}'), (Icons.door_front_door_outlined, 'KRS ${ta?['krs_dibuka'] == true ? 'dibuka' : 'ditutup'}'), (Icons.person_outline, u.nama)],
              actions: [
                BannerButton('Pengumuman', Icons.campaign_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdmPengumuman()))),
                BannerButton('Laporan', Icons.bar_chart_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdmLaporan())), outlined: true),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.75, mainAxisSpacing: 10, crossAxisSpacing: 10, children: [
              StatCard(label: 'Mahasiswa Aktif', value: '${ak['mahasiswa_aktif'] ?? 0}', icon: Icons.groups_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdmMahasiswa()))),
              StatCard(label: 'Dosen', value: '${ak['dosen'] ?? 0}', icon: Icons.badge_rounded, color: AppColors.success, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdmDosen()))),
              StatCard(label: 'Kelas Aktif', value: '${ak['kelas_aktif'] ?? 0}', icon: Icons.class_rounded, color: AppColors.info, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdmKelas()))),
              StatCard(label: 'Tunggakan', value: rupiah(d['tunggakan']), icon: Icons.money_off_rounded, color: AppColors.danger),
            ]),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Tugas Menunggu Tindakan', padding: EdgeInsets.zero,
              trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(50)), child: Text('${tugas.fold<int>(0, (a, t) => a + (t.$2 as int))}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
              child: Column(children: tugas.map((t) => ListTile(
                leading: IconBox(t.$3, color: (t.$2 as int) > 0 ? AppColors.primary : AppColors.muted),
                title: Text(t.$1, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: (t.$2 as int) > 0 ? AppColors.danger : AppColors.bg, borderRadius: BorderRadius.circular(50)), child: Text('${t.$2}', style: TextStyle(color: (t.$2 as int) > 0 ? Colors.white : AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12))),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => t.$4)),
              )).toList()),
            ),
            const SizedBox(height: 16),
            if (perProdi.isNotEmpty) SectionCard(
              title: 'Mahasiswa Aktif per Prodi',
              child: SizedBox(height: 180, child: BarChart(BarChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFEEF0F6), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(topTitles: const AxisTitles(), rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppColors.muted)))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, _) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(perProdi[v.toInt()]['prodi'].toString().split(' ').first, style: const TextStyle(fontSize: 10, color: AppColors.muted)))))),
                barGroups: [for (var i = 0; i < perProdi.length; i++) BarChartGroupData(x: i, barRods: [BarChartRodData(toY: (perProdi[i]['jumlah'] as num).toDouble(), width: 22, borderRadius: BorderRadius.circular(6), gradient: LinearGradient(colors: [_palette[i % _palette.length], _palette[i % _palette.length].withValues(alpha: .6)], begin: Alignment.bottomCenter, end: Alignment.topCenter))])],
              ))),
            ),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: SectionCard(title: 'Status Tesis', padding: const EdgeInsets.all(10), child: _Donut(tesis.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))))),
              const SizedBox(width: 10),
              Expanded(child: SectionCard(title: 'Keuangan', padding: const EdgeInsets.all(10), child: _Donut(keu.map((k, v) => MapEntry(k.toString(), (v['total'] as num).toDouble())), rupiahLabel: true))),
            ]),
            const SizedBox(height: 16),
            if (perAngkatan.isNotEmpty) SectionCard(title: 'Mahasiswa per Angkatan', child: Column(children: perAngkatan.map((a) {
              final maks = perAngkatan.fold<num>(0, (m, x) => x['jumlah'] > m ? x['jumlah'] : m);
              return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [SizedBox(width: 44, child: Text('${a['angkatan']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))), Expanded(child: ProgressBar(maks == 0 ? 0 : a['jumlah'] / maks)), const SizedBox(width: 10), Text('${a['jumlah']}', style: const TextStyle(fontSize: 13, color: AppColors.muted))]));
            }).toList())),
            const SizedBox(height: 16),
            SectionCard(title: 'Aktivitas Terbaru', padding: EdgeInsets.zero, child: Column(children: ((d['log_terbaru'] ?? []) as List).map((l) => ListTile(dense: true, leading: const Icon(Icons.history_rounded, size: 18, color: AppColors.muted), title: Text(l['aksi'], style: const TextStyle(fontSize: 12.5)), subtitle: Text('${l['service']} · ${tanggal(l['created_at'], withTime: true)}', style: const TextStyle(fontSize: 11)))).toList())),
            const SizedBox(height: 24),
          ]);
        },
      ),
    );
  }
}

class _Donut extends StatelessWidget {
  final Map<String, double> data;
  final bool rupiahLabel;
  const _Donut(this.data, {this.rupiahLabel = false});
  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const EmptyState('Belum ada data');
    final keys = data.keys.toList();
    return Column(children: [
      SizedBox(height: 120, child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 28, sections: [
        for (var i = 0; i < keys.length; i++) PieChartSectionData(value: data[keys[i]], color: _palette[i % _palette.length], radius: 26, showTitle: false),
      ]))),
      const SizedBox(height: 8),
      ...List.generate(keys.length, (i) => Padding(padding: const EdgeInsets.only(bottom: 3), child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: _palette[i % _palette.length], shape: BoxShape.circle)), const SizedBox(width: 6),
        Expanded(child: Text(cap(keys[i]), style: const TextStyle(fontSize: 10.5), overflow: TextOverflow.ellipsis)),
        Text(rupiahLabel ? rupiah(data[keys[i]]) : data[keys[i]]!.toInt().toString(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
      ]))),
    ]);
  }
}

// =============================================================== MENU
class AdmAkademikMenu extends StatelessWidget {
  const AdmAkademikMenu({super.key});
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.groups_rounded, 'Mahasiswa', 'Data & riwayat studi', AppColors.primary, const AdmMahasiswa()),
      (Icons.badge_rounded, 'Dosen', 'Data dosen & pengampu', AppColors.success, const AdmDosen()),
      (Icons.class_rounded, 'Kelas & Jadwal', 'Kelas pada TA aktif', AppColors.info, const AdmKelas()),
      (Icons.playlist_add_check_rounded, 'Verifikasi KRS', 'Setujui / tolak pengajuan', AppColors.warning, const AdmKrs()),
      (Icons.auto_stories_rounded, 'Tesis / Disertasi', 'Pembimbing & tahapan', AppColors.danger, const AdmTesis()),
      (Icons.account_tree_rounded, 'Program Studi & TA', 'Master data', const Color(0xFF8B5CF6), const AdmMaster()),
      (Icons.bar_chart_rounded, 'Laporan', 'Kinerja prodi & nilai', const Color(0xFF14B8A6), const AdmLaporan()),
    ];
    return Scaffold(appBar: AppBar(title: const Text('Akademik')), body: ListView.separated(padding: const EdgeInsets.all(16), itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (c, i) => ListTileCard(leading: IconBox(items[i].$1, color: items[i].$4), title: items[i].$2, subtitle: items[i].$3, trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => items[i].$5)))));
  }
}

class AdmLayananMenu extends StatelessWidget {
  const AdmLayananMenu({super.key});
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.mail_rounded, 'Persuratan', 'Tinjau, setujui & nomori', AppColors.primary, const AdmSurat()),
      (Icons.person_add_rounded, 'PMB / Pendaftar', 'Seleksi & buat akun', AppColors.success, const AdmPmb()),
      (Icons.campaign_rounded, 'Pengumuman', 'Publikasi informasi', AppColors.warning, const AdmPengumuman()),
      (Icons.manage_accounts_rounded, 'Pengguna', 'Akun & reset password', AppColors.danger, const AdmPengguna()),
      (Icons.public_rounded, 'Situs Publik', 'Pratinjau tampilan publik', AppColors.info, const PublicScreen()),
    ];
    return Scaffold(appBar: AppBar(title: const Text('Layanan')), body: ListView.separated(padding: const EdgeInsets.all(16), itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (c, i) => ListTileCard(leading: IconBox(items[i].$1, color: items[i].$4), title: items[i].$2, subtitle: items[i].$3, trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => items[i].$5)))));
  }
}

// =============================================================== MAHASISWA
class AdmMahasiswa extends StatefulWidget {
  const AdmMahasiswa({super.key});
  @override
  State<AdmMahasiswa> createState() => _AdmMahasiswaState();
}

class _AdmMahasiswaState extends State<AdmMahasiswa> {
  String q = '';
  String? status;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Data Mahasiswa')),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Column(children: [
            TextField(decoration: const InputDecoration(hintText: 'Cari nama / NIM...', prefixIcon: Icon(Icons.search_rounded)), onSubmitted: (v) => setState(() => q = v)),
            const SizedBox(height: 8),
            FilterChips(items: const [('', 'Semua'), ('aktif', 'Aktif'), ('cuti', 'Cuti'), ('lulus', 'Lulus'), ('nonaktif', 'Nonaktif')], selected: status ?? '', onChanged: (v) => setState(() => status = v == '' ? null : v)),
          ])),
          Expanded(child: AsyncView<Map>(
            key: ValueKey('$q$status'),
            load: () async => (await Api.I.get('/api/akademik/mahasiswa', query: {'q': q.isEmpty ? null : q, 'status': status, 'per_page': 100})) as Map,
            builder: (c, d, _) {
              final items = d['items'] as List;
              return ListView(padding: const EdgeInsets.all(16), children: [
                Text('${d['total']} mahasiswa', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 8),
                ...items.map((m) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(
                  leading: Avatar(m['nama'][0], size: 40),
                  title: Text(m['nama'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text('${m['nim']} · ${m['prodi_jenjang']} ${m['prodi_nama']}\nAngk. ${m['angkatan']} · ${m['total_sks']} SKS · IPK ${num2(m['ipk'])}', style: const TextStyle(fontSize: 11.5)),
                  isThreeLine: true, trailing: StatusBadge(m['status']),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MhsTranskrip(mahasiswaId: m['id']))),
                )))),
              ]);
            },
          )),
        ]),
      );
}

// =============================================================== DOSEN
class AdmDosen extends StatelessWidget {
  const AdmDosen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Data Dosen')),
        body: AsyncView<List>(
          load: () async => (await Api.I.get('/api/akademik/dosen')) as List,
          builder: (c, d, _) => ListView(padding: const EdgeInsets.all(16), children: d.map((x) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(
            leading: Avatar(x['nama'][0], size: 40),
            title: Text(x['nama_lengkap'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: Text('NIDN ${x['nidn']} · ${x['prodi_nama'] ?? '-'}\n${x['jabatan_fungsional'] ?? '-'} · ${x['jumlah_kelas']} kelas · ${x['jumlah_mahasiswa_pa']} PA', style: const TextStyle(fontSize: 11.5)),
            isThreeLine: true,
          )))).toList()),
        ),
      );
}

// =============================================================== KELAS
class AdmKelas extends StatelessWidget {
  const AdmKelas({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Kelas & Jadwal')),
        body: AsyncView<List>(
          load: () async => (await Api.I.get('/api/akademik/kelas')) as List,
          builder: (c, d, reload) => ListView(padding: const EdgeInsets.all(16), children: d.map((k) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(
            leading: IconBox(k['nilai_terkunci'] == true ? Icons.lock_rounded : Icons.class_rounded, color: k['nilai_terkunci'] == true ? AppColors.danger : AppColors.primary),
            title: Text('${k['nama_mk']} (${k['nama_kelas']})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: Text('${k['kode_mk']} · ${k['prodi_nama']} · ${k['dosen_nama']}\n${k['hari'] ?? '-'} ${k['jam_mulai'] ?? ''}–${k['jam_selesai'] ?? ''} · ${k['ruangan'] ?? '-'} · ${k['jumlah_peserta']}/${k['kuota']}', style: const TextStyle(fontSize: 11.5)),
            isThreeLine: true,
            trailing: IconButton(icon: Icon(k['nilai_terkunci'] == true ? Icons.lock_open_rounded : Icons.lock_outline_rounded), tooltip: 'Kunci/buka nilai', onPressed: () async { if (await runAction(context, () => Api.I.post('/api/akademik/kelas/${k['id']}/kunci-nilai'), sukses: 'Status kunci nilai diubah')) reload(); }),
          )))).toList()),
        ),
      );
}

// =============================================================== KRS
class AdmKrs extends StatefulWidget {
  const AdmKrs({super.key});
  @override
  State<AdmKrs> createState() => _AdmKrsState();
}

class _AdmKrsState extends State<AdmKrs> {
  String status = 'diajukan';
  int _ver = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Verifikasi KRS'), actions: [
          if (status == 'diajukan') TextButton(onPressed: () async {
            if (await konfirmasi(context, 'Setujui Semua', 'Setujui seluruh KRS yang diajukan pada TA aktif?')) {
              if (await runAction(context, () => Api.I.post('/api/akademik/krs/setujui-semua'), sukses: 'Semua KRS disetujui')) setState(() => _ver++);
            }
          }, child: const Text('Setujui semua')),
        ]),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: FilterChips(items: const [('diajukan', 'Diajukan'), ('disetujui', 'Disetujui'), ('ditolak', 'Ditolak')], selected: status, onChanged: (v) => setState(() => status = v!))),
          Expanded(child: AsyncView<List>(
            key: ValueKey('$status$_ver'),
            load: () async => (await Api.I.get('/api/akademik/krs', query: {'status': status})) as List,
            builder: (c, d, reload) => ListView(padding: const EdgeInsets.all(16), children: d.isEmpty ? const [EmptyState('Tidak ada KRS dengan status ini.')] : d.map((k) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text('${k['mahasiswa_nama']} (${k['nim']})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))), StatusBadge(k['status'])]),
              Text('${k['nama_mk']} · ${k['sks']} SKS · ${k['hari'] ?? '-'} ${k['jam_mulai'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              Text('Diajukan ${tanggal(k['created_at'], withTime: true)}${k['catatan'] != null ? ' · ${k['catatan']}' : ''}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              if (k['status'] != 'disetujui' || k['status'] != 'ditolak') Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
                if (k['status'] != 'disetujui') Expanded(child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(36), backgroundColor: AppColors.success), onPressed: () async { if (await runAction(context, () => Api.I.post('/api/akademik/krs/${k['id']}/setujui', body: {}), sukses: 'Disetujui')) reload(); }, child: const Text('Setujui'))),
                if (k['status'] != 'disetujui' && k['status'] != 'ditolak') const SizedBox(width: 8),
                if (k['status'] != 'ditolak') Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(36), foregroundColor: AppColors.danger, side: BorderSide(color: AppColors.danger.withValues(alpha: .5))), onPressed: () async {
                  final cat = await inputDialog(context, 'Tolak KRS', label: 'Alasan');
                  if (cat == null || !context.mounted) return;
                  if (await runAction(context, () => Api.I.post('/api/akademik/krs/${k['id']}/tolak', body: {'catatan': cat}), sukses: 'Ditolak')) reload();
                }, child: const Text('Tolak'))),
              ])),
            ]))))).toList()),
          )),
        ]),
      );
}

// =============================================================== KEUANGAN
class AdmKeuangan extends StatefulWidget {
  final String? statusAwal;
  const AdmKeuangan({super.key, this.statusAwal});
  @override
  State<AdmKeuangan> createState() => _AdmKeuanganState();
}

class _AdmKeuanganState extends State<AdmKeuangan> {
  late String? status = widget.statusAwal;
  String q = '';
  int _ver = 0;

  Future<void> _generate() async {
    final tas = (await Api.I.get('/api/akademik/tahun-akademik')) as List;
    if (!mounted) return;
    int? taId = tas.firstWhere((t) => t['aktif'] == true, orElse: () => tas.first)['id'];
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, setS) => AlertDialog(
      title: const Text('Generate Tagihan SPP'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Tagihan SPP dibuat untuk seluruh mahasiswa aktif sesuai biaya prodi. Yang sudah ada dilewati.', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(value: taId, items: tas.map((t) => DropdownMenuItem<int>(value: t['id'], child: Text(t['nama']))).toList(), onChanged: (v) => setS(() => taId = v), decoration: const InputDecoration(labelText: 'Tahun akademik')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('Generate'))],
    )));
    if (ok != true || !mounted) return;
    if (await runAction(context, () async {
      final r = await Api.I.post('/api/keuangan/generate', body: {'tahun_akademik_id': taId});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r['detail'])));
    })) setState(() => _ver++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Keuangan'), actions: [IconButton(icon: const Icon(Icons.bolt_rounded), tooltip: 'Generate SPP massal', onPressed: _generate)]),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Column(children: [
            TextField(decoration: const InputDecoration(hintText: 'Cari nama / NIM...', prefixIcon: Icon(Icons.search_rounded)), onSubmitted: (v) => setState(() => q = v)),
            const SizedBox(height: 8),
            FilterChips(items: const [('', 'Semua'), ('menunggu verifikasi', 'Menunggu'), ('belum bayar', 'Belum bayar'), ('lunas', 'Lunas'), ('ditolak', 'Ditolak')], selected: status ?? '', onChanged: (v) => setState(() => status = v == '' ? null : v)),
          ])),
          Expanded(child: AsyncView<(Map, Map)>(
            key: ValueKey('$q$status$_ver'),
            load: () async {
              final r = await Future.wait([Api.I.get('/api/keuangan/ringkasan'), Api.I.get('/api/keuangan', query: {'status': status, 'q': q.isEmpty ? null : q, 'per_page': 100})]);
              return (r[0] as Map, r[1] as Map);
            },
            builder: (c, d, reload) {
              final ring = d.$1, items = d.$2['items'] as List;
              return ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  Expanded(child: StatCard(label: 'Belum Bayar', value: rupiah(ring['belum bayar']?['total']), icon: Icons.error_outline_rounded, color: AppColors.danger)),
                  const SizedBox(width: 8),
                  Expanded(child: StatCard(label: 'Menunggu', value: rupiah(ring['menunggu verifikasi']?['total']), icon: Icons.hourglass_top_rounded, color: AppColors.warning)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: StatCard(label: 'Lunas', value: rupiah(ring['lunas']?['total']), icon: Icons.check_circle_outline_rounded, color: AppColors.success)),
                  const SizedBox(width: 8),
                  Expanded(child: StatCard(label: 'Ditolak', value: rupiah(ring['ditolak']?['total']), icon: Icons.cancel_outlined, color: AppColors.muted)),
                ]),
                const SizedBox(height: 12),
                Text('${d.$2['total']} tagihan', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 8),
                if (items.isEmpty) const EmptyState('Tidak ada tagihan.'),
                ...items.map((t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text('${t['mahasiswa_nama']} (${t['nim']})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))), StatusBadge(t['status'])]),
                  Text('${t['jenis']} · ${t['tahun_akademik'] ?? '-'}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  Row(children: [Text(rupiah(t['jumlah']), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 15)), const Spacer(), Text('JT ${tanggal(t['jatuh_tempo'])}', style: TextStyle(fontSize: 11, color: t['terlambat'] == true ? AppColors.danger : AppColors.muted))]),
                  if (t['bukti_bayar'] != null) Text('Bukti: ${Api.I.fileUrl(t['bukti_bayar'])}', style: const TextStyle(fontSize: 10.5, color: AppColors.info), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (t['catatan'] != null && t['catatan'].toString().isNotEmpty) Text(t['catatan'], style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                  if (t['status'] != 'lunas') Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
                    Expanded(child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(36), backgroundColor: AppColors.success), onPressed: () async { if (await runAction(context, () => Api.I.post('/api/keuangan/${t['id']}/verifikasi'), sukses: 'Pembayaran diverifikasi (lunas)')) reload(); }, child: Text(t['status'] == 'menunggu verifikasi' ? 'Verifikasi' : 'Tandai Lunas'))),
                    const SizedBox(width: 8),
                    if (t['status'] == 'menunggu verifikasi') Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(36), foregroundColor: AppColors.danger, side: BorderSide(color: AppColors.danger.withValues(alpha: .5))), onPressed: () async {
                      final cat = await inputDialog(context, 'Tolak Bukti', label: 'Alasan', awal: 'Bukti pembayaran tidak valid');
                      if (cat == null || !context.mounted) return;
                      if (await runAction(context, () => Api.I.post('/api/keuangan/${t['id']}/tolak', body: {'catatan': cat}), sukses: 'Pembayaran ditolak')) reload();
                    }, child: const Text('Tolak'))),
                  ])),
                ]))))),
              ]);
            },
          )),
        ]),
      );
}

// =============================================================== TESIS
class AdmTesis extends StatefulWidget {
  final String? statusAwal;
  const AdmTesis({super.key, this.statusAwal});
  @override
  State<AdmTesis> createState() => _AdmTesisState();
}

class _AdmTesisState extends State<AdmTesis> {
  late String? status = widget.statusAwal;
  int _ver = 0;

  Future<void> _kelola(Map t) async {
    final dosen = (await Api.I.get('/api/akademik/dosen')) as List;
    if (!mounted) return;
    int? p1 = t['pembimbing1_id'], p2 = t['pembimbing2_id'];
    String st = t['status'];
    final cat = TextEditingController(text: t['catatan']), nilai = TextEditingController(text: t['nilai_akhir']?.toString());
    const semua = ['pengajuan', 'disetujui', 'proposal', 'penelitian', 'seminar hasil', 'ujian', 'selesai', 'ditolak'];
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(t['mahasiswa_nama'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(t['judul'], style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(value: p1, isExpanded: true, decoration: const InputDecoration(labelText: 'Pembimbing 1'), items: dosen.map((d) => DropdownMenuItem<int>(value: d['id'], child: Text(d['nama_lengkap'], style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setS(() => p1 = v)),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(value: p2, isExpanded: true, decoration: const InputDecoration(labelText: 'Pembimbing 2'), items: dosen.map((d) => DropdownMenuItem<int>(value: d['id'], child: Text(d['nama_lengkap'], style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setS(() => p2 = v)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: st, decoration: const InputDecoration(labelText: 'Status'), items: semua.map((s) => DropdownMenuItem(value: s, child: Text(cap(s)))).toList(), onChanged: (v) => setS(() => st = v!)),
        const SizedBox(height: 10),
        TextField(controller: nilai, decoration: const InputDecoration(labelText: 'Nilai akhir (0-100)'), keyboardType: TextInputType.number),
        const SizedBox(height: 10),
        TextField(controller: cat, decoration: const InputDecoration(labelText: 'Catatan untuk mahasiswa'), maxLines: 2),
        const SizedBox(height: 14),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
      ]),
    )));
    if (ok != true || !mounted) return;
    if (await runAction(context, () => Api.I.put('/api/tesis/${t['id']}', body: {'pembimbing1_id': p1, 'pembimbing2_id': p2, 'status': st, 'catatan': cat.text, 'nilai_akhir': double.tryParse(nilai.text)}), sukses: 'Tesis diperbarui')) setState(() => _ver++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tesis / Disertasi')),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: FilterChips(items: const [('', 'Semua'), ('pengajuan', 'Pengajuan'), ('disetujui', 'Disetujui'), ('proposal', 'Proposal'), ('penelitian', 'Penelitian'), ('seminar hasil', 'Seminar'), ('ujian', 'Ujian'), ('selesai', 'Selesai')], selected: status ?? '', onChanged: (v) => setState(() => status = v == '' ? null : v))),
          Expanded(child: AsyncView<List>(
            key: ValueKey('$status$_ver'),
            load: () async => (await Api.I.get('/api/tesis', query: {'status': status})) as List,
            builder: (c, d, _) => ListView(padding: const EdgeInsets.all(16), children: d.isEmpty ? const [EmptyState('Belum ada pengajuan tesis.')] : d.map((t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: InkWell(borderRadius: BorderRadius.circular(18), onTap: () => _kelola(t), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text('${t['mahasiswa_nama']} (${t['nim']})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))), StatusBadge(t['status'])]),
              const SizedBox(height: 4),
              Text(t['judul'], style: const TextStyle(fontSize: 12.5), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text('P1: ${t['pembimbing1_nama'] ?? 'Belum'} · P2: ${t['pembimbing2_nama'] ?? '-'}', style: TextStyle(fontSize: 11.5, color: t['pembimbing1_id'] == null ? AppColors.danger : AppColors.muted)),
              const SizedBox(height: 6),
              ProgressBar((t['progres'] ?? 0) / 100),
            ])))))).toList()),
          )),
        ]),
      );
}

// =============================================================== SURAT
/// Peninjauan persuratan: admin membaca isi yang disusun mahasiswa lalu menyetujui / minta revisi / menolak.
class AdmSurat extends StatefulWidget {
  const AdmSurat({super.key});
  @override
  State<AdmSurat> createState() => _AdmSuratState();
}

class _AdmSuratState extends State<AdmSurat> {
  String? status = 'diajukan';
  int _ver = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Peninjauan Surat')),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: FilterChips(items: const [('diajukan', 'Menunggu'), ('revisi', 'Revisi'), ('disetujui', 'Disetujui'), ('ditolak', 'Ditolak'), ('', 'Semua')], selected: status ?? '', onChanged: (v) => setState(() => status = v == '' ? null : v))),
          Expanded(child: AsyncView<List>(
            key: ValueKey('$status$_ver'),
            load: () async => (await Api.I.get('/api/layanan/persuratan', query: {'status': status})) as List,
            builder: (c, d, _) => ListView(padding: const EdgeInsets.all(16), children: d.isEmpty ? const [EmptyState('Tidak ada surat pada status ini.')] : d.map((s) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(
              leading: IconBox(Icons.description_outlined, color: AppColors.status(s['status'])),
              title: Text('${s['nama']} (${s['nim']})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text('${s['jenis']} · ${s['program_studi']}\n${s['diajukan_at'] != null ? 'Diajukan ${tanggal(s['diajukan_at'], withTime: true)}' : 'Diubah ${tanggal(s['updated_at'], withTime: true)}'}${s['nomor_surat'] != null ? ' · ${s['nomor_surat']}' : ''}', style: const TextStyle(fontSize: 11.5)),
              isThreeLine: true, trailing: StatusBadge(s['status']),
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => AdmSuratDetail(s['id'])));
                setState(() => _ver++);
              },
            )))).toList()),
          )),
        ]),
      );
}

class AdmSuratDetail extends StatefulWidget {
  final int id;
  const AdmSuratDetail(this.id, {super.key});
  @override
  State<AdmSuratDetail> createState() => _AdmSuratDetailState();
}

class _AdmSuratDetailState extends State<AdmSuratDetail> {
  int _ver = 0;

  Future<void> _setujui(Map s) async {
    final usul = await Api.I.get('/api/layanan/persuratan/${widget.id}/nomor-usulan') as Map;
    if (!mounted) return;
    final nomor = TextEditingController(text: usul['nomor_surat']), hijriah = TextEditingController(text: usul['tanggal_hijriah']), cat = TextEditingController();
    DateTime tgl = DateTime.parse(usul['tanggal_surat']);
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, setS) => AlertDialog(
      title: const Text('Setujui & Terbitkan'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${s['nama']} (${s['nim']})\n${s['jenis']}', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        const SizedBox(height: 12),
        TextField(controller: nomor, decoration: const InputDecoration(labelText: 'Nomor surat', helperText: 'Usulan otomatis, dapat diubah')),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final p = await showDatePicker(context: c, initialDate: tgl, firstDate: DateTime(2020), lastDate: DateTime(2100), locale: const Locale('id', 'ID'));
            if (p == null) return;
            final u = await Api.I.get('/api/layanan/persuratan/${widget.id}/nomor-usulan', query: {'tanggal': '${p.year}-${p.month.toString().padLeft(2, '0')}-${p.day.toString().padLeft(2, '0')}'}) as Map;
            setS(() { tgl = p; nomor.text = u['nomor_surat']; hijriah.text = u['tanggal_hijriah']; });
          },
          child: InputDecorator(decoration: const InputDecoration(labelText: 'Tanggal surat (Masehi)', suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)), child: Text(tanggal(tgl), style: const TextStyle(fontSize: 14))),
        ),
        const SizedBox(height: 10),
        TextField(controller: hijriah, decoration: const InputDecoration(labelText: 'Tanggal Hijriah', helperText: 'Perkiraan kalender; sesuaikan bila perlu')),
        const SizedBox(height: 10),
        TextField(controller: cat, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('Setujui'))],
    )));
    if (ok != true || !mounted) return;
    if (await runAction(context, () => Api.I.patch('/api/layanan/persuratan/${widget.id}/tinjau', body: {
          'aksi': 'setujui', 'nomor_surat': nomor.text.trim(), 'tanggal_hijriah': hijriah.text.trim(),
          'tanggal_surat': '${tgl.year}-${tgl.month.toString().padLeft(2, '0')}-${tgl.day.toString().padLeft(2, '0')}',
          'catatan': cat.text.trim().isEmpty ? null : cat.text.trim(),
        }), sukses: 'Surat disetujui & diberi nomor')) setState(() => _ver++);
  }

  Future<void> _tolakAtauRevisi(String aksi) async {
    final cat = await inputDialog(context, aksi == 'revisi' ? 'Minta Revisi' : 'Tolak Surat', label: aksi == 'revisi' ? 'Bagian yang perlu diperbaiki mahasiswa *' : 'Alasan penolakan *', maxLines: 3);
    if (cat == null || cat.trim().isEmpty || !mounted) return;
    if (await runAction(context, () => Api.I.patch('/api/layanan/persuratan/${widget.id}/tinjau', body: {'aksi': aksi, 'catatan': cat.trim()}), sukses: aksi == 'revisi' ? 'Dikembalikan ke mahasiswa untuk revisi' : 'Surat ditolak')) setState(() => _ver++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tinjau Surat')),
        body: AsyncView<(Map, Map)>(
          key: ValueKey(_ver),
          load: () async {
            final r = await Future.wait([Api.I.get('/api/layanan/persuratan/${widget.id}'), Api.I.get('/api/layanan/persuratan/${widget.id}/dokumen')]);
            return (r[0] as Map, r[1] as Map);
          },
          builder: (c, d, _) {
            final s = d.$1, bisaTinjau = s['status'] == 'diajukan' || s['status'] == 'revisi';
            return ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [Expanded(child: Text(s['jenis'], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))), StatusBadge(s['status'])]),
              const SizedBox(height: 4),
              Text('${s['nama']} (${s['nim']})${s['diajukan_at'] != null ? ' · Diajukan ${tanggal(s['diajukan_at'], withTime: true)}' : ''}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              if (s['keperluan'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Keperluan: ${s['keperluan']}', style: const TextStyle(fontSize: 12.5))),
              if (s['catatan_admin'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Catatan (${s['ditinjau_oleh'] ?? 'admin'}): ${s['catatan_admin']}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
              const SizedBox(height: 14),
              SectionCard(title: 'Data yang diisi mahasiswa', child: Column(children: [
                InfoRow('Nama', s['nama']), InfoRow('NIM', s['nim']),
                InfoRow('Tempat, Tgl Lahir', '${s['tempat_lahir'] ?? '-'}, ${tanggal(s['tanggal_lahir'])}'),
                InfoRow('Asal Sekolah', s['asal_sekolah'] ?? '-'), InfoRow('Program', s['program_pendidikan']), InfoRow('Prodi', s['program_studi']),
                InfoRow('Semester / TA', '${s['semester']} ${s['tahun_ajaran']}'),
                if (s['nomor_surat'] != null) InfoRow('Nomor surat', s['nomor_surat']),
                if (s['tanggal_surat'] != null) InfoRow('Tanggal surat', '${s['tanggal_hijriah']} / ${tanggal(s['tanggal_surat'])}'),
              ])),
              const SizedBox(height: 12),
              SuratDokumenView(d.$2),
              const SizedBox(height: 16),
              if (bisaTinjau) Column(children: [
                FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)), onPressed: () => _setujui(s), icon: const Icon(Icons.verified_rounded), label: const Text('Setujui & Terbitkan Nomor')),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)), onPressed: () => _tolakAtauRevisi('revisi'), icon: const Icon(Icons.undo_rounded), label: const Text('Minta Revisi'))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), foregroundColor: AppColors.danger), onPressed: () => _tolakAtauRevisi('tolak'), icon: const Icon(Icons.close_rounded), label: const Text('Tolak'))),
                ]),
              ]),
            ]);
          },
        ),
      );
}

// =============================================================== PMB
class AdmPmb extends StatefulWidget {
  const AdmPmb({super.key});
  @override
  State<AdmPmb> createState() => _AdmPmbState();
}

class _AdmPmbState extends State<AdmPmb> {
  String? status;
  int _ver = 0;
  Future<void> _proses(Map p) async {
    String st = p['status'];
    bool buatAkun = false;
    final cat = TextEditingController(text: p['catatan']);
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, setS) => AlertDialog(
      title: Text(p['nama']),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${p['nomor_pendaftaran']} · ${p['prodi_nama']}\n${p['pendidikan_terakhir']} · IPK ${p['ipk_terakhir'] ?? '-'}\n${p['email']} · ${p['telepon']}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        if (p['rencana_penelitian'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(p['rencana_penelitian'], style: const TextStyle(fontSize: 12))),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: st, decoration: const InputDecoration(labelText: 'Status seleksi'), items: ['baru', 'diverifikasi', 'lulus seleksi', 'tidak lulus', 'diterima'].map((x) => DropdownMenuItem(value: x, child: Text(cap(x)))).toList(), onChanged: (v) => setS(() => st = v!)),
        const SizedBox(height: 10),
        TextField(controller: cat, decoration: const InputDecoration(labelText: 'Catatan')),
        if (st == 'diterima' && p['mahasiswa_id'] == null) CheckboxListTile(contentPadding: EdgeInsets.zero, value: buatAkun, onChanged: (v) => setS(() => buatAkun = v!), title: const Text('Buat akun mahasiswa otomatis', style: TextStyle(fontSize: 13))),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('Simpan'))],
    )));
    if (ok != true || !mounted) return;
    if (await runAction(context, () async {
      final r = await Api.I.patch('/api/layanan/pmb/${p['id']}', body: {'status': st, 'catatan': cat.text, 'buat_akun': buatAkun});
      if (buatAkun && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r['catatan'] ?? 'Akun dibuat'), duration: const Duration(seconds: 6)));
    }, sukses: 'Pendaftar diperbarui')) setState(() => _ver++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('PMB / Pendaftar')),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: FilterChips(items: const [('', 'Semua'), ('baru', 'Baru'), ('diverifikasi', 'Diverifikasi'), ('lulus seleksi', 'Lulus'), ('diterima', 'Diterima'), ('tidak lulus', 'Tidak lulus')], selected: status ?? '', onChanged: (v) => setState(() => status = v == '' ? null : v))),
          Expanded(child: AsyncView<List>(
            key: ValueKey('$status$_ver'),
            load: () async => (await Api.I.get('/api/layanan/pmb', query: {'status': status})) as List,
            builder: (c, d, _) => ListView(padding: const EdgeInsets.all(16), children: d.isEmpty ? const [EmptyState('Belum ada pendaftar.')] : d.map((p) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(
              leading: Avatar(p['nama'][0], size: 40),
              title: Text(p['nama'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text('${p['nomor_pendaftaran']} · ${p['prodi_nama']}\n${p['pendidikan_terakhir']} · IPK ${p['ipk_terakhir'] ?? '-'}', style: const TextStyle(fontSize: 11.5)),
              isThreeLine: true, trailing: StatusBadge(p['status']), onTap: () => _proses(p),
            )))).toList()),
          )),
        ]),
      );
}

// =============================================================== PENGUMUMAN
class AdmPengumuman extends StatefulWidget {
  const AdmPengumuman({super.key});
  @override
  State<AdmPengumuman> createState() => _AdmPengumumanState();
}

class _AdmPengumumanState extends State<AdmPengumuman> {
  int _ver = 0;
  Future<void> _form([Map? p]) async {
    final judul = TextEditingController(text: p?['judul']), isi = TextEditingController(text: p?['isi']);
    String kat = p?['kategori'] ?? 'Umum', target = p?['target'] ?? 'semua';
    bool penting = p?['penting'] ?? false;
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(p == null ? 'Buat Pengumuman' : 'Ubah Pengumuman', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        TextField(controller: judul, decoration: const InputDecoration(labelText: 'Judul *')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: kat, decoration: const InputDecoration(labelText: 'Kategori'), items: ['Umum', 'Akademik', 'Keuangan', 'Tesis', 'Beasiswa', 'Kegiatan'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setS(() => kat = v!))),
          const SizedBox(width: 8),
          Expanded(child: DropdownButtonFormField<String>(value: target, decoration: const InputDecoration(labelText: 'Target'), items: ['semua', 'mahasiswa', 'dosen', 'publik'].map((x) => DropdownMenuItem(value: x, child: Text(cap(x)))).toList(), onChanged: (v) => setS(() => target = v!))),
        ]),
        const SizedBox(height: 10),
        TextField(controller: isi, decoration: const InputDecoration(labelText: 'Isi pengumuman *'), maxLines: 5),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: penting, onChanged: (v) => setS(() => penting = v), title: const Text('Penting / disematkan', style: TextStyle(fontSize: 13))),
        FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.send_rounded), label: Text(p == null ? 'Terbitkan & Kirim Notifikasi' : 'Simpan')),
      ]),
    )));
    if (ok != true || !mounted) return;
    final body = {'judul': judul.text, 'isi': isi.text, 'kategori': kat, 'target': target, 'penting': penting};
    if (await runAction(context, () => p == null ? Api.I.post('/api/layanan/pengumuman', body: body) : Api.I.put('/api/layanan/pengumuman/${p['id']}', body: body), sukses: 'Pengumuman tersimpan')) setState(() => _ver++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pengumuman')),
        floatingActionButton: FloatingActionButton.extended(onPressed: () => _form(), backgroundColor: AppColors.primary, foregroundColor: Colors.white, icon: const Icon(Icons.add_rounded), label: const Text('Buat')),
        body: AsyncView<List>(
          key: ValueKey(_ver),
          load: () async => (await Api.I.get('/api/layanan/pengumuman/untuk-saya', query: {'limit': 100})) as List,
          builder: (c, d, reload) => ListView(padding: const EdgeInsets.all(16), children: [
            ...d.map((p) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(
              leading: IconBox(p['penting'] == true ? Icons.push_pin_rounded : Icons.campaign_outlined, color: p['penting'] == true ? AppColors.danger : AppColors.primary),
              title: Text(p['judul'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text('${p['kategori']} · ${cap(p['target'])} · ${tanggal(p['created_at'])}', style: const TextStyle(fontSize: 11.5)),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') _form(p);
                  if (v == 'hapus' && await konfirmasi(context, 'Hapus', 'Hapus pengumuman ini?', bahaya: true) && context.mounted) {
                    if (await runAction(context, () => Api.I.delete('/api/layanan/pengumuman/${p['id']}'), sukses: 'Dihapus')) reload();
                  }
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Ubah')), PopupMenuItem(value: 'hapus', child: Text('Hapus', style: TextStyle(color: AppColors.danger)))],
              ),
            )))),
            const SizedBox(height: 80),
          ]),
        ),
      );
}

// =============================================================== PENGGUNA
class AdmPengguna extends StatefulWidget {
  const AdmPengguna({super.key});
  @override
  State<AdmPengguna> createState() => _AdmPenggunaState();
}

class _AdmPenggunaState extends State<AdmPengguna> {
  String? role;
  int _ver = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pengguna')),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: FilterChips(items: const [('', 'Semua'), ('admin', 'Staf'), ('dosen', 'Dosen'), ('mahasiswa', 'Mahasiswa')], selected: role ?? '', onChanged: (v) => setState(() => role = v == '' ? null : v))),
          Expanded(child: AsyncView<List>(
            key: ValueKey('$role$_ver'),
            load: () async => (await Api.I.get('/api/users', query: {'role': role})) as List,
            builder: (c, d, reload) => ListView(padding: const EdgeInsets.all(16), children: d.map((u) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(
              leading: Avatar(u['nama'][0], size: 40),
              title: Text(u['nama'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text('${u['username']} · ${cap(u['role'])} · ${u['email']}\nLogin terakhir: ${tanggal(u['last_login'], withTime: true)}', style: const TextStyle(fontSize: 11.5)),
              isThreeLine: true,
              trailing: u['id'] == Session.I.user!.id ? const Text('Anda', style: TextStyle(fontSize: 11, color: AppColors.muted)) : PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'reset' && await konfirmasi(context, 'Reset Password', 'Reset password ${u['username']} menjadi sama dengan username?') && context.mounted) {
                    if (await runAction(context, () => Api.I.patch('/api/users/${u['id']}', body: {'reset_password': true}), sukses: 'Password direset')) reload();
                  }
                  if (v == 'toggle' && context.mounted) {
                    if (await runAction(context, () => Api.I.patch('/api/users/${u['id']}', body: {'aktif': !(u['aktif'] as bool)}), sukses: 'Status akun diubah')) reload();
                  }
                },
                itemBuilder: (_) => [const PopupMenuItem(value: 'reset', child: Text('Reset password')), PopupMenuItem(value: 'toggle', child: Text(u['aktif'] ? 'Nonaktifkan' : 'Aktifkan', style: TextStyle(color: u['aktif'] ? AppColors.danger : AppColors.success)))],
              ),
            )))).toList()),
          )),
        ]),
      );
}

// =============================================================== MASTER & LAPORAN
class AdmMaster extends StatefulWidget {
  const AdmMaster({super.key});
  @override
  State<AdmMaster> createState() => _AdmMasterState();
}

class _AdmMasterState extends State<AdmMaster> {
  int _ver = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Program Studi & Tahun Akademik')),
        body: AsyncView<(List, List)>(
          key: ValueKey(_ver),
          load: () async {
            final r = await Future.wait([Api.I.get('/api/akademik/prodi'), Api.I.get('/api/akademik/tahun-akademik')]);
            return (r[0] as List, r[1] as List);
          },
          builder: (c, d, reload) => ListView(padding: const EdgeInsets.all(16), children: [
            SectionCard(title: 'Tahun Akademik', padding: EdgeInsets.zero, child: Column(children: d.$2.map((t) => ListTile(
              leading: IconBox(Icons.calendar_month_rounded, color: t['aktif'] ? AppColors.success : AppColors.muted),
              title: Text(t['nama'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text('${tanggal(t['tanggal_mulai'])} – ${tanggal(t['tanggal_selesai'])} · KRS ${t['krs_dibuka'] ? 'dibuka' : 'ditutup'}', style: const TextStyle(fontSize: 11.5)),
              trailing: t['aktif'] ? PopupMenuButton<String>(
                onSelected: (v) async { if (await runAction(context, () => Api.I.post('/api/akademik/tahun-akademik/${t['id']}/toggle-krs'), sukses: 'Periode KRS diubah')) setState(() => _ver++); },
                itemBuilder: (_) => [PopupMenuItem(value: 'krs', child: Text(t['krs_dibuka'] ? 'Tutup KRS' : 'Buka KRS'))],
              ) : TextButton(onPressed: () async { if (await konfirmasi(context, 'Aktifkan', 'Aktifkan ${t['nama']} sebagai TA berjalan?')) { if (await runAction(context, () => Api.I.post('/api/akademik/tahun-akademik/${t['id']}/aktifkan'), sukses: 'TA diaktifkan')) setState(() => _ver++); } }, child: const Text('Aktifkan')),
            )).toList())),
            const SizedBox(height: 12),
            SectionCard(title: 'Program Studi', padding: EdgeInsets.zero, child: Column(children: d.$1.map((p) => ListTile(
              leading: Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: (p['jenjang'] == 'S3' ? AppColors.danger : AppColors.primary).withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Text(p['jenjang'], style: TextStyle(fontWeight: FontWeight.w800, color: p['jenjang'] == 'S3' ? AppColors.danger : AppColors.primary))),
              title: Text(p['nama'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text('${p['kode']} · Akreditasi ${p['akreditasi'] ?? '-'} · ${p['jumlah_mahasiswa']} mhs · ${p['jumlah_matakuliah']} MK\n${rupiah(p['biaya_semester'])}/smt · Kaprodi: ${p['kaprodi_nama'] ?? '-'}', style: const TextStyle(fontSize: 11.5)),
              isThreeLine: true,
            )).toList())),
          ]),
        ),
      );
}

class AdmLaporan extends StatelessWidget {
  const AdmLaporan({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Laporan Akademik')),
        body: AsyncView<(List, Map, List)>(
          load: () async {
            final r = await Future.wait([Api.I.get('/api/akademik/laporan/prodi'), Api.I.get('/api/akademik/laporan/distribusi-nilai'), Api.I.get('/api/akademik/laporan/progres-nilai')]);
            return (r[0] as List, r[1] as Map, r[2] as List);
          },
          builder: (c, d, _) {
            const urut = ['A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'D', 'E'];
            final maks = urut.fold<num>(1, (m, h) => (d.$2[h] ?? 0) > m ? d.$2[h] : m);
            return ListView(padding: const EdgeInsets.all(16), children: [
              SectionCard(title: 'Kinerja per Program Studi', padding: EdgeInsets.zero, child: Column(children: d.$1.map((r) => ListTile(
                title: Text('${r['jenjang']} ${r['prodi']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: Text('Aktif ${r['aktif']} · Lulus ${r['lulus']}', style: const TextStyle(fontSize: 11.5)),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('Rata IPK', style: TextStyle(fontSize: 10, color: AppColors.muted)), Text(num2(r['rata_ipk']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary))]),
              )).toList())),
              const SizedBox(height: 12),
              SectionCard(title: 'Distribusi Nilai Huruf', child: Column(children: urut.map((h) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [SizedBox(width: 28, child: Text(h, style: const TextStyle(fontWeight: FontWeight.w800))), Expanded(child: ProgressBar((d.$2[h] ?? 0) / maks, color: _palette[urut.indexOf(h) % _palette.length])), const SizedBox(width: 10), SizedBox(width: 30, child: Text('${d.$2[h] ?? 0}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: AppColors.muted)))]))).toList())),
              const SizedBox(height: 12),
              SectionCard(title: 'Progres Penilaian Kelas', child: Column(children: d.$3.map((r) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(r['kelas']['nama'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))), Text('${r['dinilai']}/${r['peserta']}${r['rata'] != null ? ' · rata ${r['rata']}' : ''}', style: const TextStyle(fontSize: 11.5, color: AppColors.muted))]),
                const SizedBox(height: 5),
                ProgressBar(r['peserta'] == 0 ? 0 : r['dinilai'] / r['peserta'], color: r['peserta'] > 0 && r['dinilai'] == r['peserta'] ? AppColors.success : null),
              ]))).toList())),
            ]);
          },
        ),
      );
}
