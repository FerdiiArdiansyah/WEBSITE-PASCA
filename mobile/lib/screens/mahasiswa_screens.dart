import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'auth_screens.dart';
import 'public_screen.dart';

/// Shell navigasi bawah untuk mahasiswa.
class MahasiswaShell extends StatefulWidget {
  const MahasiswaShell({super.key});
  @override
  State<MahasiswaShell> createState() => _MahasiswaShellState();
}

class _MahasiswaShellState extends State<MahasiswaShell> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [const MhsDashboard(), const MhsAkademikMenu(), const MhsKeuangan(), const MhsTesis(), const ProfilScreen()];
    return Scaffold(
      body: IndexedStack(index: _i, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i, onDestinationSelected: (i) => setState(() => _i = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'Kuliah'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Bayar'),
          NavigationDestination(icon: Icon(Icons.auto_stories_outlined), selectedIcon: Icon(Icons.auto_stories_rounded), label: 'Tesis'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}

// =============================================================== DASHBOARD
class MhsDashboard extends StatelessWidget {
  const MhsDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    final u = Session.I.user!;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [Avatar(u.inisial, size: 34), const SizedBox(width: 10), Expanded(child: Text('Halo, ${u.namaDepan}!', overflow: TextOverflow.ellipsis))]),
        actions: [IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotifikasiScreen())))],
      ),
      body: AsyncView<Map>(
        load: () async => (await Api.I.get('/api/dashboard/mahasiswa')) as Map,
        builder: (c, d, _) {
          final ak = d['akademik'] ?? {}, m = ak['mahasiswa'] ?? {}, keu = d['keuangan'] ?? {}, tesis = d['tesis'];
          final ips = (ak['ips_per_semester'] ?? []) as List;
          final jadwal = (ak['jadwal_hari_ini'] ?? []) as List;
          return ListView(padding: const EdgeInsets.all(16), children: [
            WelcomeBanner(
              title: m['nama'] ?? u.nama, subtitle: '${m['prodi_jenjang'] ?? ''} ${m['prodi_nama'] ?? ''} · Semester ${m['semester_ke'] ?? '-'}',
              pills: [(Icons.badge_outlined, m['nim'] ?? u.username), (Icons.calendar_month_outlined, ak['tahun_akademik'] ?? '-'), (Icons.person_pin_outlined, 'PA: ${m['dosen_pa_nama'] ?? '-'}')],
              actions: [
                BannerButton('Isi KRS', Icons.playlist_add_check_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MhsKrs()))),
                BannerButton('Lihat KHS', Icons.description_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MhsKhs())), outlined: true),
              ],
            ),
            if ((keu['jumlah_belum'] ?? 0) > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: .1), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Anda memiliki ${keu['jumlah_belum']} tagihan belum lunas senilai ${rupiah(keu['belum'])}.', style: const TextStyle(fontSize: 12.5, color: Color(0xFF9F1239), fontWeight: FontWeight.w600))),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.75, mainAxisSpacing: 10, crossAxisSpacing: 10,
              children: [
                StatCard(label: 'IPK', value: num2(m['ipk']), icon: Icons.trending_up_rounded, color: AppColors.primary),
                StatCard(label: 'SKS Lulus', value: '${m['total_sks'] ?? 0}', icon: Icons.task_alt_rounded, color: AppColors.success),
                StatCard(label: 'SKS Semester', value: '${ak['sks_semester'] ?? 0}', icon: Icons.playlist_add_check_rounded, color: AppColors.info, sub: '${ak['krs_disetujui'] ?? 0}/${ak['krs_total'] ?? 0} disetujui'),
                StatCard(label: 'Keuangan', value: (keu['belum'] ?? 0) == 0 ? 'Lunas' : rupiah(keu['belum']), icon: Icons.account_balance_wallet_rounded, color: (keu['belum'] ?? 0) == 0 ? AppColors.success : AppColors.danger),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Jadwal Hari Ini',
              trailing: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MhsJadwal())), child: const Text('Semua')),
              padding: EdgeInsets.zero,
              child: jadwal.isEmpty
                  ? const EmptyState('Tidak ada kuliah hari ini.', icon: Icons.event_available_rounded)
                  : Column(children: jadwal.map((k) => ListTile(
                      leading: const IconBox(Icons.schedule_rounded),
                      title: Text(k['nama_mk'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      subtitle: Text('${k['dosen_nama']} · ${k['hari']}', style: const TextStyle(fontSize: 11.5)),
                      trailing: Chip(label: Text('${k['jam_mulai']}–${k['jam_selesai']}', style: const TextStyle(fontSize: 11, color: Colors.white)), backgroundColor: AppColors.primary, padding: EdgeInsets.zero),
                    )).toList()),
            ),
            const SizedBox(height: 16),
            if (ips.isNotEmpty)
              SectionCard(
                title: 'Perkembangan IPS',
                child: SizedBox(
                  height: 170,
                  child: LineChart(LineChartData(
                    minY: 0, maxY: 4,
                    gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFEEF0F6), strokeWidth: 1)),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(), rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1, getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppColors.muted)))),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= ips.length) return const SizedBox();
                        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(ips[i]['tahun_akademik'].toString().replaceAll(RegExp(r'^\d{4}/'), '').replaceAll(' Ganjil', 'Gj').replaceAll(' Genap', 'Gn'), style: const TextStyle(fontSize: 9.5, color: AppColors.muted)));
                      })),
                    ),
                    lineBarsData: [LineChartBarData(
                      spots: [for (var i = 0; i < ips.length; i++) FlSpot(i.toDouble(), (ips[i]['ips'] as num).toDouble())],
                      isCurved: true, color: AppColors.primary, barWidth: 3,
                      dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 5, color: AppColors.gold, strokeWidth: 2, strokeColor: Colors.white)),
                      belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: .3), AppColors.primary.withValues(alpha: 0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                    )],
                  )),
                ),
              ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Tesis / Disertasi',
              child: tesis == null
                  ? const Text('Anda belum mengajukan judul tesis.', style: TextStyle(color: AppColors.muted, fontSize: 13))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tesis['judul'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      const SizedBox(height: 8),
                      Row(children: [StatusBadge(tesis['status']), const Spacer(), Text('${tesis['progres']}%', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary))]),
                      const SizedBox(height: 8),
                      ProgressBar((tesis['progres'] ?? 0) / 100),
                      const SizedBox(height: 6),
                      Text('${tesis['jumlah_bimbingan_disetujui']} bimbingan disetujui', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                    ]),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Agenda Akademik', padding: EdgeInsets.zero,
              child: (d['agenda'] as List).isEmpty
                  ? const EmptyState('Tidak ada agenda mendatang.')
                  : Column(children: (d['agenda'] as List).map((k) => ListTile(dense: true, leading: const IconBox(Icons.event_rounded, color: AppColors.sky), title: Text(k['kegiatan'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), subtitle: Text(tanggal(k['tanggal_mulai']), style: const TextStyle(fontSize: 11.5)))).toList()),
            ),
            const SizedBox(height: 16),
            SectionCard(title: 'Pengumuman', padding: const EdgeInsets.fromLTRB(12, 12, 12, 4), child: Column(children: (d['pengumuman'] as List).map((p) => PengumumanTile(p)).toList())),
            const SizedBox(height: 24),
          ]);
        },
      ),
    );
  }
}

// =============================================================== MENU AKADEMIK
class MhsAkademikMenu extends StatelessWidget {
  const MhsAkademikMenu({super.key});
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.playlist_add_check_rounded, 'Kartu Rencana Studi', 'Ajukan & pantau KRS', AppColors.primary, const MhsKrs()),
      (Icons.calendar_view_week_rounded, 'Jadwal Kuliah', 'Jadwal per hari', AppColors.sky, const MhsJadwal()),
      (Icons.fact_check_outlined, 'Presensi', 'Rekap kehadiran', AppColors.success, const MhsPresensi()),
      (Icons.description_outlined, 'KHS', 'Hasil studi per semester', AppColors.warning, const MhsKhs()),
      (Icons.workspace_premium_outlined, 'Transkrip', 'Seluruh nilai & IPK', AppColors.danger, const MhsTranskrip()),
      (Icons.mail_outline_rounded, 'Pengajuan Surat', 'Surat keterangan & izin', const Color(0xFF8B5CF6), const MhsSurat()),
      (Icons.campaign_outlined, 'Pengumuman', 'Info resmi pascasarjana', const Color(0xFF14B8A6), const PengumumanScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Akademik')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16), itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (c, i) => ListTileCard(
          leading: IconBox(items[i].$1, color: items[i].$4), title: items[i].$2, subtitle: items[i].$3, trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => items[i].$5)),
        ),
      ),
    );
  }
}

class PengumumanScreen extends StatelessWidget {
  const PengumumanScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pengumuman')),
        body: AsyncView<List>(
          load: () async => (await Api.I.get('/api/layanan/pengumuman/untuk-saya')) as List,
          builder: (c, d, _) => ListView(padding: const EdgeInsets.all(16), children: d.isEmpty ? const [EmptyState('Belum ada pengumuman.')] : d.map((p) => PengumumanTile(p)).toList()),
        ),
      );
}

// =============================================================== KRS
class MhsKrs extends StatelessWidget {
  const MhsKrs({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Kartu Rencana Studi')),
        body: AsyncView<(List, List, Map?)>(
          load: () async {
            final r = await Future.wait([Api.I.get('/api/akademik/krs/saya'), Api.I.get('/api/akademik/krs/tersedia'), Api.I.get('/api/akademik/tahun-akademik/aktif')]);
            return (r[0] as List, r[1] as List, r[2] as Map?);
          },
          builder: (c, d, reload) {
            final saya = d.$1, tersedia = d.$2, ta = d.$3;
            final sks = saya.where((k) => k['status'] != 'ditolak').fold<int>(0, (a, k) => a + (k['sks'] as int));
            return ListView(padding: const EdgeInsets.all(16), children: [
              if (ta != null && ta['krs_dibuka'] != true)
                Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
                    child: const Row(children: [Icon(Icons.lock_outline, color: AppColors.warning), SizedBox(width: 8), Expanded(child: Text('Periode pengisian KRS sedang ditutup.', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)))])),
              SectionCard(
                title: 'KRS Saya — ${ta?['nama'] ?? '-'}',
                trailing: Chip(label: Text('$sks / 15 SKS', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)), backgroundColor: AppColors.primary, padding: EdgeInsets.zero),
                padding: EdgeInsets.zero,
                child: saya.isEmpty
                    ? const EmptyState('Belum ada mata kuliah yang diambil.')
                    : Column(children: saya.map((k) => ListTile(
                        title: Text(k['nama_mk'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        subtitle: Text('${k['kode_mk']} · ${k['sks']} SKS · ${k['hari'] ?? '-'} ${k['jam_mulai'] ?? ''}\n${k['dosen_nama']}', style: const TextStyle(fontSize: 11.5)),
                        isThreeLine: true,
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          StatusBadge(k['status']),
                          if (k['nilai_akhir'] == null && (ta?['krs_dibuka'] ?? false))
                            SizedBox(height: 28, child: TextButton(style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: AppColors.danger), onPressed: () async {
                              if (await konfirmasi(context, 'Batalkan', 'Batalkan ${k['nama_mk']}?', bahaya: true)) {
                                if (await runAction(context, () => Api.I.delete('/api/akademik/krs/${k['id']}'), sukses: 'Dibatalkan')) reload();
                              }
                            }, child: const Text('Batalkan', style: TextStyle(fontSize: 11)))),
                        ]),
                      )).toList()),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Mata Kuliah Tersedia', padding: EdgeInsets.zero,
                child: tersedia.isEmpty
                    ? const EmptyState('Tidak ada kelas tersedia.')
                    : Column(children: tersedia.map((k) => ListTile(
                        title: Text(k['nama_mk'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        subtitle: Text('${k['kode_mk']} · ${k['sks']} SKS · Smt ${k['semester_ke'] ?? ''} · ${k['hari'] ?? '-'} ${k['jam_mulai'] ?? ''}\n${k['dosen_nama']} · Sisa kuota ${k['sisa_kuota']}', style: const TextStyle(fontSize: 11.5)),
                        isThreeLine: true,
                        trailing: FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size(70, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
                          onPressed: (k['sisa_kuota'] ?? 0) <= 0 || !(ta?['krs_dibuka'] ?? false) ? null : () async {
                            if (await runAction(context, () => Api.I.post('/api/akademik/krs', body: {'kelas_id': k['id']}), sukses: 'Diajukan, menunggu persetujuan')) reload();
                          },
                          child: const Text('Ambil'),
                        ),
                      )).toList()),
              ),
            ]);
          },
        ),
      );
}

// =============================================================== JADWAL
class JadwalView extends StatelessWidget {
  final String title, endpoint;
  final bool showDosen;
  const JadwalView({super.key, required this.title, required this.endpoint, this.showDosen = true});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: AsyncView<Map>(
          load: () async => (await Api.I.get(endpoint)) as Map,
          builder: (c, d, _) {
            final hariIni = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'][DateTime.now().weekday - 1];
            return ListView(padding: const EdgeInsets.all(16), children: d.entries.map((e) {
              final kelas = (e.value as List);
              final aktif = e.key == hariIni;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: aktif ? AppColors.primary : const Color(0xFFE9ECF5), width: aktif ? 1.5 : 1)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Row(children: [
                      Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      if (aktif) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(50)), child: const Text('Hari ini', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)))],
                    ])),
                    if (kelas.isEmpty) const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 14), child: Text('Tidak ada jadwal', style: TextStyle(color: AppColors.muted, fontSize: 12.5))),
                    ...kelas.map((k) => ListTile(
                      dense: true, leading: const IconBox(Icons.schedule_rounded),
                      title: Text(k['nama_mk'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      subtitle: Text('${k['jam_mulai']}–${k['jam_selesai']} · ${k['ruangan'] ?? '-'}${showDosen ? '\n${k['dosen_nama']}' : ' · Kelas ${k['nama_kelas']}'}', style: const TextStyle(fontSize: 11.5)),
                    )),
                  ]),
                ),
              );
            }).toList());
          },
        ),
      );
}

class MhsJadwal extends StatelessWidget {
  const MhsJadwal({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<List>(
        load: () async => (await Api.I.get('/api/akademik/krs/saya')) as List,
        builder: (c, krs, _) {
          final per = {for (final h in ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu']) h: krs.where((k) => k['status'] == 'disetujui' && k['hari'] == h).toList()..sort((a, b) => (a['jam_mulai'] ?? '').compareTo(b['jam_mulai'] ?? ''))};
          return _JadwalStatic(per);
        },
      );
}

class _JadwalStatic extends StatelessWidget {
  final Map<String, List> per;
  const _JadwalStatic(this.per);
  @override
  Widget build(BuildContext context) {
    final hariIni = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'][DateTime.now().weekday - 1];
    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal Kuliah')),
      body: ListView(padding: const EdgeInsets.all(16), children: per.entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: e.key == hariIni ? AppColors.primary : const Color(0xFFE9ECF5), width: e.key == hariIni ? 1.5 : 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            if (e.value.isEmpty) const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 14), child: Text('Tidak ada jadwal', style: TextStyle(color: AppColors.muted, fontSize: 12.5))),
            ...e.value.map((k) => ListTile(dense: true, leading: const IconBox(Icons.schedule_rounded),
                title: Text(k['nama_mk'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: Text('${k['jam_mulai']}–${k['jam_selesai']} · ${k['dosen_nama']}', style: const TextStyle(fontSize: 11.5)))),
          ]),
        ),
      )).toList()),
    );
  }
}

// =============================================================== PRESENSI
class MhsPresensi extends StatelessWidget {
  const MhsPresensi({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Rekap Presensi')),
        body: AsyncView<List>(
          load: () async => (await Api.I.get('/api/akademik/presensi/saya')) as List,
          builder: (c, d, _) => ListView(padding: const EdgeInsets.all(16), children: d.isEmpty ? const [EmptyState('Belum ada kelas disetujui semester ini.')] : d.map((r) {
            final persen = r['persen'];
            final hitung = r['hitung'] as Map;
            final data = r['data'] as Map;
            return Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(r['kelas']['nama_mk'], style: const TextStyle(fontWeight: FontWeight.w700))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (persen == null ? AppColors.muted : (persen >= 75 ? AppColors.success : AppColors.danger)).withValues(alpha: .12), borderRadius: BorderRadius.circular(50)),
                    child: Text(persen == null ? 'Belum ada' : '$persen%', style: TextStyle(fontWeight: FontWeight.w800, color: persen == null ? AppColors.muted : (persen >= 75 ? AppColors.success : AppColors.danger)))),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 10, children: [
                _H('Hadir', hitung['hadir'], AppColors.success), _H('Izin', hitung['izin'], AppColors.info), _H('Sakit', hitung['sakit'], AppColors.muted), _H('Alpa', hitung['alpa'], AppColors.danger),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: (r['pertemuan'] as List).map((p) {
                final s = data['${p['id']}'] ?? data[p['id']];
                final col = AppColors.status(s);
                return Tooltip(message: '${p['materi'] ?? ''}\n${tanggal(p['tanggal'])}', child: Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: s == null ? const Color(0xFFEEF0F6) : col.withValues(alpha: .15), borderRadius: BorderRadius.circular(8), border: Border.all(color: s == null ? const Color(0xFFE3E6F0) : col)),
                    child: Text('${p['pertemuan_ke']}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: s == null ? AppColors.muted : col))));
              }).toList()),
              if (persen != null && persen < 75) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Kehadiran di bawah 75% — berisiko tidak memenuhi syarat ujian akhir.', style: TextStyle(fontSize: 11.5, color: AppColors.danger.withValues(alpha: .9), fontWeight: FontWeight.w600))),
            ]))));
          }).toList()),
        ),
      );
}

class _H extends StatelessWidget {
  final String l;
  final dynamic n;
  final Color c;
  const _H(this.l, this.n, this.c);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)), const SizedBox(width: 4), Text('$l ${n ?? 0}', style: const TextStyle(fontSize: 12))]);
}

// =============================================================== KHS & TRANSKRIP
class NilaiTile extends StatelessWidget {
  final Map k;
  const NilaiTile(this.k, {super.key});
  @override
  Widget build(BuildContext context) {
    final huruf = k['nilai_huruf'];
    final c = huruf == null ? AppColors.muted : (huruf.startsWith('A') ? AppColors.success : huruf.startsWith('B') ? AppColors.primary : huruf.startsWith('C') ? AppColors.warning : AppColors.danger);
    return ListTile(
      dense: true,
      leading: Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Text(huruf ?? '-', style: TextStyle(fontWeight: FontWeight.w800, color: c, fontSize: 15))),
      title: Text(k['nama_mk'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      subtitle: Text('${k['kode_mk']} · ${k['sks']} SKS${k['nilai_akhir'] != null ? ' · Nilai ${k['nilai_akhir']}' : ''}', style: const TextStyle(fontSize: 11.5)),
      trailing: k['bobot'] == null ? null : Text(num2(k['bobot']), style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class MhsKhs extends StatefulWidget {
  const MhsKhs({super.key});
  @override
  State<MhsKhs> createState() => _MhsKhsState();
}

class _MhsKhsState extends State<MhsKhs> {
  int? taId;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Kartu Hasil Studi')),
        body: AsyncView<(List, Map)>(
          key: ValueKey(taId),
          load: () async {
            final tas = (await Api.I.get('/api/akademik/tahun-akademik')) as List;
            final khs = await Api.I.get('/api/akademik/nilai/khs', query: {'tahun_akademik_id': taId});
            return (tas, khs as Map);
          },
          builder: (c, d, _) {
            final tas = d.$1, khs = d.$2;
            return ListView(padding: const EdgeInsets.all(16), children: [
              DropdownButtonFormField<int>(
                value: khs['tahun_akademik_id'], decoration: const InputDecoration(labelText: 'Semester'),
                items: tas.map((t) => DropdownMenuItem<int>(value: t['id'], child: Text(t['nama']))).toList(), onChanged: (v) => setState(() => taId = v),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StatCard(label: 'IPS', value: num2(khs['ips']), icon: Icons.trending_up_rounded)),
                const SizedBox(width: 10),
                Expanded(child: StatCard(label: 'SKS', value: '${khs['sks']}', icon: Icons.task_alt_rounded, color: AppColors.success)),
              ]),
              const SizedBox(height: 12),
              SectionCard(title: 'Nilai Mata Kuliah', padding: EdgeInsets.zero, child: (khs['daftar'] as List).isEmpty ? const EmptyState('Belum ada nilai pada semester ini.') : Column(children: (khs['daftar'] as List).map((k) => NilaiTile(k)).toList())),
            ]);
          },
        ),
      );
}

class MhsTranskrip extends StatelessWidget {
  final int? mahasiswaId;
  const MhsTranskrip({super.key, this.mahasiswaId});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Transkrip Akademik')),
        body: AsyncView<Map>(
          load: () async => (await Api.I.get('/api/akademik/nilai/transkrip', query: {'mahasiswa_id': mahasiswaId})) as Map,
          builder: (c, d, _) {
            final m = d['mahasiswa'];
            return ListView(padding: const EdgeInsets.all(16), children: [
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                const Text('UNIVERSITAS MUHAMMADIYAH MAKASSAR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: .5)),
                const Text('Program Pascasarjana — Transkrip Akademik Sementara', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                const Divider(height: 20),
                InfoRow('Nama', m['nama']), InfoRow('NIM', m['nim']), InfoRow('Program Studi', '${m['prodi_jenjang']} ${m['prodi_nama']}'), InfoRow('Angkatan', '${m['angkatan']}'),
              ]))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StatCard(label: 'IPK', value: num2(d['ipk']), icon: Icons.workspace_premium_rounded)),
                const SizedBox(width: 10),
                Expanded(child: StatCard(label: 'Total SKS', value: '${d['total_sks']}', icon: Icons.task_alt_rounded, color: AppColors.success)),
              ]),
              const SizedBox(height: 12),
              ...(d['semester'] as List).map((s) => Padding(padding: const EdgeInsets.only(bottom: 10), child: SectionCard(
                title: s['tahun_akademik'], trailing: Text('IPS ${num2(s['ips'])} · ${s['sks']} SKS', style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
                padding: EdgeInsets.zero, child: Column(children: (s['daftar'] as List).map((k) => NilaiTile(k)).toList()),
              ))),
            ]);
          },
        ),
      );
}

// =============================================================== KEUANGAN
class MhsKeuangan extends StatelessWidget {
  const MhsKeuangan({super.key});

  Future<void> _bayar(BuildContext context, Map t, Future<void> Function() reload) async {
    final pick = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'], withData: true);
    if (pick == null || pick.files.single.bytes == null) return;
    final f = pick.files.single;
    if (!context.mounted) return;
    final catatan = await inputDialog(context, 'Konfirmasi Pembayaran', label: 'Catatan (nama pengirim / bank)');
    if (catatan == null || !context.mounted) return;
    if (await runAction(context, () => Api.I.multipart('/api/keuangan/saya/${t['id']}/bayar', fields: {'catatan': catatan}, files: {'bukti': (f.bytes!, f.name)}), sukses: 'Bukti terkirim, menunggu verifikasi')) reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Keuangan')),
        body: AsyncView<(List, Map)>(
          load: () async {
            final r = await Future.wait([Api.I.get('/api/keuangan/saya'), Api.I.get('/api/keuangan/saya/ringkasan')]);
            return (r[0] as List, r[1] as Map);
          },
          builder: (c, d, reload) => ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Expanded(child: StatCard(label: 'Belum Dibayar', value: rupiah(d.$2['belum']), icon: Icons.error_outline_rounded, color: (d.$2['belum'] ?? 0) > 0 ? AppColors.danger : AppColors.success)),
              const SizedBox(width: 10),
              Expanded(child: StatCard(label: 'Total Lunas', value: rupiah(d.$2['lunas']), icon: Icons.check_circle_outline_rounded, color: AppColors.success)),
            ]),
            const SizedBox(height: 12),
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
              const IconBox(Icons.account_balance_rounded, color: AppColors.gold), const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Rekening Pembayaran', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text(d.$2['rekening'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.muted))])),
            ]))),
            const SizedBox(height: 12),
            ...d.$1.map((t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(t['jenis'], style: const TextStyle(fontWeight: FontWeight.w700))), StatusBadge(t['status'])]),
              Text(t['tahun_akademik'] ?? '-', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 8),
              Row(children: [
                Text(rupiah(t['jumlah']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const Spacer(),
                Text('Jatuh tempo ${tanggal(t['jatuh_tempo'])}', style: TextStyle(fontSize: 11.5, color: t['terlambat'] == true ? AppColors.danger : AppColors.muted, fontWeight: t['terlambat'] == true ? FontWeight.w700 : null)),
              ]),
              if (t['catatan'] != null && t['catatan'].toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(t['catatan'], style: const TextStyle(fontSize: 11.5, color: AppColors.muted))),
              if (t['status'] == 'belum bayar' || t['status'] == 'ditolak') ...[
                const SizedBox(height: 10),
                FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(42)), onPressed: () => _bayar(context, t, reload), icon: const Icon(Icons.upload_file_rounded, size: 18), label: const Text('Unggah Bukti Pembayaran')),
              ],
            ]))))),
            if (d.$1.isEmpty) const EmptyState('Tidak ada tagihan.'),
          ]),
        ),
      );
}

// =============================================================== TESIS
class MhsTesis extends StatelessWidget {
  const MhsTesis({super.key});

  Future<void> _ajukan(BuildContext context, Future<void> Function() reload) async {
    final judul = TextEditingController(), abstrak = TextEditingController(), bidang = TextEditingController();
    PlatformFile? file;
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Pengajuan Judul Tesis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(controller: judul, decoration: const InputDecoration(labelText: 'Judul penelitian *'), maxLines: 2),
          const SizedBox(height: 10),
          TextField(controller: bidang, decoration: const InputDecoration(labelText: 'Bidang / topik kajian')),
          const SizedBox(height: 10),
          TextField(controller: abstrak, decoration: const InputDecoration(labelText: 'Ringkasan / latar belakang *'), maxLines: 4),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final p = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
              if (p != null) setS(() => file = p.files.single);
            },
            icon: const Icon(Icons.attach_file_rounded), label: Text(file?.name ?? 'Lampirkan proposal (PDF, opsional)'),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajukan Judul')),
        ]),
      )),
    );
    if (ok != true || !context.mounted) return;
    if (await runAction(context, () => Api.I.multipart('/api/tesis/saya', fields: {'judul': judul.text, 'abstrak': abstrak.text, 'bidang': bidang.text},
        files: file?.bytes == null ? {} : {'file_proposal': (file!.bytes!, file!.name)}), sukses: 'Judul diajukan, menunggu penetapan pembimbing')) reload();
  }

  Future<void> _bimbingan(BuildContext context, Map t, Future<void> Function() reload) async {
    final topik = TextEditingController(), catatan = TextEditingController();
    int? dosenId = t['pembimbing1_id'];
    PlatformFile? file;
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Ajukan Bimbingan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            value: dosenId, decoration: const InputDecoration(labelText: 'Pembimbing'),
            items: [
              if (t['pembimbing1_id'] != null) DropdownMenuItem(value: t['pembimbing1_id'] as int, child: Text('${t['pembimbing1_nama']} (P1)')),
              if (t['pembimbing2_id'] != null) DropdownMenuItem(value: t['pembimbing2_id'] as int, child: Text('${t['pembimbing2_nama']} (P2)')),
            ],
            onChanged: (v) => setS(() => dosenId = v),
          ),
          const SizedBox(height: 10),
          TextField(controller: topik, decoration: const InputDecoration(labelText: 'Topik / bab yang dibahas *')),
          const SizedBox(height: 10),
          TextField(controller: catatan, decoration: const InputDecoration(labelText: 'Catatan / progres yang dikerjakan'), maxLines: 3),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final p = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
              if (p != null) setS(() => file = p.files.single);
            },
            icon: const Icon(Icons.attach_file_rounded), label: Text(file?.name ?? 'Lampiran (PDF, opsional)'),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kirim')),
        ]),
      )),
    );
    if (ok != true || !context.mounted || dosenId == null) return;
    if (await runAction(context, () => Api.I.multipart('/api/tesis/saya/bimbingan', fields: {'dosen_id': '$dosenId', 'topik': topik.text, 'catatan_mahasiswa': catatan.text},
        files: file?.bytes == null ? {} : {'lampiran': (file!.bytes!, file!.name)}), sukses: 'Pengajuan bimbingan terkirim')) reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tesis / Disertasi')),
        body: AsyncView<Map?>(
          load: () async => (await Api.I.get('/api/tesis/saya')) as Map?,
          builder: (c, t, reload) {
            if (t == null || t['status'] == 'ditolak') {
              return ListView(padding: const EdgeInsets.all(16), children: [
                if (t != null) Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)), child: Text('Pengajuan sebelumnya ditolak. ${t['catatan'] ?? ''} Silakan ajukan judul baru.', style: const TextStyle(fontSize: 12.5))),
                Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
                  const Icon(Icons.auto_stories_rounded, size: 56, color: AppColors.primary),
                  const SizedBox(height: 12),
                  const Text('Belum ada pengajuan tesis', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text('Syarat: minimal 12 SKS lulus. Ajukan judul, lalu admin menetapkan pembimbing.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: () => _ajukan(context, reload), icon: const Icon(Icons.add_rounded), label: const Text('Ajukan Judul')),
                ]))),
                const SizedBox(height: 16),
                SectionCard(title: 'Alur Penyelesaian', child: const TahapanTesis(status: null)),
              ]);
            }
            final bimb = (t['bimbingan'] ?? []) as List;
            final bisaBimbingan = !['pengajuan', 'ditolak', 'selesai'].contains(t['status']);
            return ListView(padding: const EdgeInsets.all(16), children: [
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(t['judul'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))), StatusBadge(t['status'])]),
                const SizedBox(height: 6),
                Text('Bidang: ${t['bidang'] ?? '-'} · Diajukan ${tanggal(t['tanggal_pengajuan'])}', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                const SizedBox(height: 10),
                ProgressBar((t['progres'] ?? 0) / 100),
                const SizedBox(height: 4),
                Text('Progres ${t['progres']}%${t['tanggal_ujian'] != null ? ' · Ujian ${tanggal(t['tanggal_ujian'])}' : ''}${t['nilai_akhir'] != null ? ' · Nilai ${t['nilai_akhir']}' : ''}', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                const Divider(height: 20),
                InfoRow('Pembimbing 1', t['pembimbing1_nama'] ?? 'Belum ditetapkan'),
                InfoRow('Pembimbing 2', t['pembimbing2_nama'] ?? '-'),
                if (t['catatan'] != null) Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)), child: Text('Catatan: ${t['catatan']}', style: const TextStyle(fontSize: 12))),
                if (bisaBimbingan) ...[const SizedBox(height: 12), FilledButton.icon(onPressed: () => _bimbingan(context, t, reload), icon: const Icon(Icons.add_comment_outlined), label: const Text('Ajukan Bimbingan'))],
              ]))),
              const SizedBox(height: 12),
              SectionCard(title: 'Tahapan', child: TahapanTesis(status: t['status'])),
              const SizedBox(height: 12),
              SectionCard(title: 'Log Bimbingan (${bimb.length})', child: bimb.isEmpty ? const Text('Belum ada bimbingan.', style: TextStyle(color: AppColors.muted, fontSize: 13)) : Column(children: bimb.map((b) => BimbinganItem(b)).toList())),
            ]);
          },
        ),
      );
}

class TahapanTesis extends StatelessWidget {
  final String? status;
  const TahapanTesis({super.key, required this.status});
  static const urutan = ['pengajuan', 'disetujui', 'proposal', 'penelitian', 'seminar hasil', 'ujian', 'selesai'];
  @override
  Widget build(BuildContext context) {
    final idx = status == null ? -1 : urutan.indexOf(status!);
    return Column(children: [
      for (var i = 0; i < urutan.length; i++)
        Row(children: [
          Column(children: [
            Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, color: i <= idx ? AppColors.primary : Colors.white, border: Border.all(color: i <= idx ? AppColors.primary : const Color(0xFFCBD5E1), width: 2)),
                child: i < idx ? const Icon(Icons.check, size: 13, color: Colors.white) : null),
            if (i < urutan.length - 1) Container(width: 2, height: 22, color: i < idx ? AppColors.primary : const Color(0xFFE2E8F0)),
          ]),
          const SizedBox(width: 12),
          Padding(padding: const EdgeInsets.only(bottom: 22), child: Row(children: [
            Text(cap(urutan[i]), style: TextStyle(fontWeight: i == idx ? FontWeight.w800 : FontWeight.w500, color: i == idx ? AppColors.primary : (i < idx ? AppColors.text : AppColors.muted), fontSize: 13)),
            if (i == idx) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(50)), child: const Text('Saat ini', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)))],
          ])),
        ]),
    ]);
  }
}

class BimbinganItem extends StatelessWidget {
  final Map b;
  final Widget? action;
  const BimbinganItem(this.b, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14), border: Border(left: BorderSide(color: AppColors.status(b['status']), width: 4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(b['topik'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))), StatusBadge(b['status'])]),
          Text('${tanggal(b['tanggal'])} · ${b['dosen_nama']}', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          if (b['catatan_mahasiswa'] != null && b['catatan_mahasiswa'].toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Mahasiswa: ${b['catatan_mahasiswa']}', style: const TextStyle(fontSize: 12))),
          if (b['catatan_dosen'] != null && b['catatan_dosen'].toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Dosen: ${b['catatan_dosen']}', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600))),
          if (action != null) Padding(padding: const EdgeInsets.only(top: 8), child: action!),
        ]),
      );
}

// =============================================================== SURAT
class MhsSurat extends StatelessWidget {
  const MhsSurat({super.key});

  Future<void> _ajukan(BuildContext context, List jenis, Future<void> Function() reload) async {
    String? j = jenis.isNotEmpty ? jenis.first : null;
    final kep = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Ajukan Surat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(value: j, decoration: const InputDecoration(labelText: 'Jenis surat'), items: jenis.map((x) => DropdownMenuItem<String>(value: x, child: Text(x, style: const TextStyle(fontSize: 13)))).toList(), onChanged: (v) => setS(() => j = v)),
          const SizedBox(height: 10),
          TextField(controller: kep, decoration: const InputDecoration(labelText: 'Keperluan / tujuan *'), maxLines: 3),
          const SizedBox(height: 14),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajukan')),
        ]),
      )),
    );
    if (ok != true || !context.mounted) return;
    if (await runAction(context, () => Api.I.post('/api/layanan/surat/saya', body: {'jenis': j, 'keperluan': kep.text}), sukses: 'Pengajuan surat terkirim')) reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pengajuan Surat')),
        body: AsyncView<(List, List)>(
          load: () async {
            final r = await Future.wait([Api.I.get('/api/layanan/surat/saya'), Api.I.get('/api/layanan/surat/jenis')]);
            return (r[0] as List, r[1] as List);
          },
          builder: (c, d, reload) => Scaffold(
            floatingActionButton: FloatingActionButton.extended(onPressed: () => _ajukan(context, d.$2, reload), icon: const Icon(Icons.add_rounded), label: const Text('Ajukan Surat'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            body: ListView(padding: const EdgeInsets.all(16), children: d.$1.isEmpty ? const [EmptyState('Belum ada pengajuan surat.')] : d.$1.map((s) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(child: ListTile(
              leading: IconBox(Icons.mail_outline_rounded, color: AppColors.status(s['status'])),
              title: Text(s['jenis'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text('${s['keperluan']}\n${tanggal(s['created_at'])}${s['nomor_surat'] != null ? ' · No. ${s['nomor_surat']}' : ''}${s['catatan'] != null ? '\n${s['catatan']}' : ''}', style: const TextStyle(fontSize: 11.5)),
              isThreeLine: true, trailing: StatusBadge(s['status']),
              onTap: s['status'] != 'selesai' ? null : () async {
                final doc = await Api.I.get('/api/layanan/surat/saya/${s['id']}/dokumen');
                if (!context.mounted) return;
                showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => SuratPreview(doc));
              },
            )))).toList()),
          ),
        ),
      );
}

class SuratPreview extends StatelessWidget {
  final Map d;
  const SuratPreview(this.d, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = d['surat'], m = d['mahasiswa'], inst = d['institusi'];
    return DraggableScrollableSheet(expand: false, initialChildSize: .85, builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(24, 0, 24, 40), children: [
      Center(child: Column(children: [
        Text(inst['universitas'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        Text(inst['nama'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Text('${inst['alamat']} · ${inst['telepon']}', style: const TextStyle(fontSize: 10, color: AppColors.muted), textAlign: TextAlign.center),
      ])),
      const Divider(thickness: 2, color: Colors.black, height: 24),
      Center(child: Column(children: [Text(s['jenis'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, decoration: TextDecoration.underline)), Text('Nomor: ${s['nomor_surat']}', style: const TextStyle(fontSize: 12))])),
      const SizedBox(height: 16),
      const Text('Yang bertanda tangan di bawah ini, Direktur Program Pascasarjana, menerangkan bahwa:', style: TextStyle(fontSize: 13, height: 1.5)),
      const SizedBox(height: 8),
      InfoRow('Nama', m['nama']), InfoRow('NIM', m['nim']), InfoRow('Program Studi', '${m['prodi_jenjang']} ${m['prodi_nama']}'), InfoRow('Semester', '${m['semester_ke']}'), InfoRow('Status', cap(m['status'])),
      const SizedBox(height: 8),
      Text('adalah benar mahasiswa aktif Program Pascasarjana ${inst['universitas']}. Surat ini dibuat untuk keperluan: ${s['keperluan']}.', style: const TextStyle(fontSize: 13, height: 1.5)),
      const SizedBox(height: 20),
      Align(alignment: Alignment.centerRight, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Makassar, ${tanggal(d['tanggal_terbit'])}', style: const TextStyle(fontSize: 12)), const Text('Direktur,', style: TextStyle(fontSize: 12)), const SizedBox(height: 40), const Text('Prof. Dr. H. Direktur Pascasarjana, M.Pd.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, decoration: TextDecoration.underline))])),
    ]));
  }
}
