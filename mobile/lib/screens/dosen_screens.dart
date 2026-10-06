import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'auth_screens.dart';
import 'mahasiswa_screens.dart';
import 'public_screen.dart';

class DosenShell extends StatefulWidget {
  const DosenShell({super.key});
  @override
  State<DosenShell> createState() => _DosenShellState();
}

class _DosenShellState extends State<DosenShell> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [const DsnDashboard(), const DsnKelasList(), const DsnBimbinganList(), const DsnPerwalian(), const ProfilScreen()];
    return Scaffold(
      body: IndexedStack(index: _i, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i, onDestinationSelected: (i) => setState(() => _i = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.class_outlined), selectedIcon: Icon(Icons.class_rounded), label: 'Kelas'),
          NavigationDestination(icon: Icon(Icons.auto_stories_outlined), selectedIcon: Icon(Icons.auto_stories_rounded), label: 'Bimbingan'),
          NavigationDestination(icon: Icon(Icons.supervisor_account_outlined), selectedIcon: Icon(Icons.supervisor_account_rounded), label: 'PA'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}

// =============================================================== DASHBOARD
class DsnDashboard extends StatelessWidget {
  const DsnDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    final u = Session.I.user!;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [Avatar(u.inisial, size: 34), const SizedBox(width: 10), const Expanded(child: Text('Dashboard Dosen'))]),
        actions: [IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotifikasiScreen())))],
      ),
      body: AsyncView<Map>(
        load: () async => (await Api.I.get('/api/dashboard/dosen')) as Map,
        builder: (c, d, _) {
          final ak = d['akademik'] ?? {}, ds = ak['dosen'] ?? {};
          final jadwal = (ak['jadwal_hari_ini'] ?? []) as List, progres = (ak['progres_nilai'] ?? []) as List;
          final logP = (d['log_menunggu'] ?? []) as List, bimb = (d['bimbingan_aktif'] ?? []) as List;
          return ListView(padding: const EdgeInsets.all(16), children: [
            WelcomeBanner(
              title: ds['nama_lengkap'] ?? u.nama, subtitle: 'Ringkasan perkuliahan dan pembimbingan semester ini.', icon: Icons.co_present_rounded,
              pills: [(Icons.calendar_month_outlined, ak['tahun_akademik'] ?? '-'), (Icons.account_tree_outlined, ds['prodi'] ?? '-'), (Icons.military_tech_outlined, ds['jabatan'] ?? 'Dosen')],
            ),
            const SizedBox(height: 16),
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.75, mainAxisSpacing: 10, crossAxisSpacing: 10, children: [
              StatCard(label: 'Kelas Diampu', value: '${ak['jumlah_kelas'] ?? 0}', icon: Icons.class_rounded),
              StatCard(label: 'Mahasiswa', value: '${ak['jumlah_mahasiswa'] ?? 0}', icon: Icons.groups_rounded, color: AppColors.success),
              StatCard(label: 'Bimbingan', value: '${bimb.length}', icon: Icons.auto_stories_rounded, color: AppColors.info, sub: '${logP.length} log menunggu'),
              StatCard(label: 'Mahasiswa PA', value: '${ak['mahasiswa_pa'] ?? 0}', icon: Icons.supervisor_account_rounded, color: AppColors.warning, sub: '${ak['krs_menunggu'] ?? 0} KRS menunggu'),
            ]),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Jadwal Mengajar Hari Ini', padding: EdgeInsets.zero,
              trailing: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JadwalView(title: 'Jadwal Mengajar', endpoint: '/api/akademik/dosen/me/jadwal', showDosen: false))), child: const Text('Semua')),
              child: jadwal.isEmpty ? const EmptyState('Tidak ada jadwal mengajar hari ini.', icon: Icons.event_available_rounded) : Column(children: jadwal.map((k) => ListTile(
                leading: const IconBox(Icons.schedule_rounded), title: Text(k['nama'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: Text('${k['ruangan'] ?? '-'} · ${k['jumlah_peserta']} mahasiswa', style: const TextStyle(fontSize: 11.5)),
                trailing: Chip(label: Text('${k['jam_mulai']}–${k['jam_selesai']}', style: const TextStyle(fontSize: 11, color: Colors.white)), backgroundColor: AppColors.primary, padding: EdgeInsets.zero),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DsnKelasDetail(kelas: k))),
              )).toList()),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Progres Input Nilai',
              child: progres.isEmpty ? const Text('Belum ada kelas semester ini.', style: TextStyle(color: AppColors.muted, fontSize: 13)) : Column(children: progres.map((p) {
                final total = p['total'] ?? 0, dinilai = p['dinilai'] ?? 0;
                return Padding(padding: const EdgeInsets.only(bottom: 12), child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DsnKelasDetail(kelas: p['kelas']))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text(p['kelas']['nama'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))), Text('$dinilai/$total', style: const TextStyle(fontSize: 12, color: AppColors.muted))]),
                    const SizedBox(height: 6),
                    ProgressBar(total == 0 ? 0 : dinilai / total, color: total > 0 && dinilai == total ? AppColors.success : null),
                  ]),
                ));
              }).toList()),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Log Bimbingan Menunggu', padding: EdgeInsets.zero,
              trailing: logP.isEmpty ? null : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(50)), child: Text('${logP.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
              child: logP.isEmpty ? const EmptyState('Tidak ada log yang menunggu.', icon: Icons.check_circle_outline_rounded) : Column(children: logP.map((b) => ListTile(
                leading: const IconBox(Icons.pending_actions_rounded, color: AppColors.warning),
                title: Text(b['topik'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)), subtitle: Text(tanggal(b['tanggal']), style: const TextStyle(fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DsnBimbinganDetail(tesisId: b['tesis_id']))),
              )).toList()),
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

// =============================================================== KELAS
class DsnKelasList extends StatelessWidget {
  const DsnKelasList({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Kelas Saya')),
        body: AsyncView<List>(
          load: () async => (await Api.I.get('/api/akademik/dosen/me/kelas')) as List,
          builder: (c, d, _) => ListView(padding: const EdgeInsets.all(16), children: d.isEmpty ? const [EmptyState('Tidak ada kelas pada semester ini.')] : d.map((k) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(child: InkWell(
            borderRadius: BorderRadius.circular(18), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DsnKelasDetail(kelas: k))),
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE3E6F0))), child: Text(k['kode_mk'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)), child: Text('Kelas ${k['nama_kelas']}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700))),
                const Spacer(),
                if (k['nilai_terkunci'] == true) const Icon(Icons.lock_rounded, size: 16, color: AppColors.danger),
              ]),
              const SizedBox(height: 8),
              Text(k['nama_mk'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text('${k['prodi_nama']} · ${k['sks']} SKS', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.schedule_rounded, size: 14, color: AppColors.muted), const SizedBox(width: 4), Text('${k['hari'] ?? '-'}, ${k['jam_mulai'] ?? ''}–${k['jam_selesai'] ?? ''} · ${k['ruangan'] ?? '-'}', style: const TextStyle(fontSize: 12)),
              ]),
              Row(children: [
                const Icon(Icons.groups_rounded, size: 14, color: AppColors.muted), const SizedBox(width: 4), Text('${k['jumlah_peserta']} mahasiswa · ${k['jumlah_pertemuan']} pertemuan', style: const TextStyle(fontSize: 12)),
              ]),
            ])),
          )))).toList()),
        ),
      );
}

class DsnKelasDetail extends StatefulWidget {
  final Map kelas;
  const DsnKelasDetail({super.key, required this.kelas});
  @override
  State<DsnKelasDetail> createState() => _DsnKelasDetailState();
}

class _DsnKelasDetailState extends State<DsnKelasDetail> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.kelas['nama'] ?? widget.kelas['nama_mk']),
          bottom: TabBar(controller: _tab, labelColor: AppColors.primary, indicatorColor: AppColors.primary, tabs: const [Tab(text: 'Input Nilai'), Tab(text: 'Presensi')]),
        ),
        body: TabBarView(controller: _tab, children: [_NilaiTab(widget.kelas), _PresensiTab(widget.kelas)]),
      );
}

class _NilaiTab extends StatefulWidget {
  final Map kelas;
  const _NilaiTab(this.kelas);
  @override
  State<_NilaiTab> createState() => _NilaiTabState();
}

class _NilaiTabState extends State<_NilaiTab> {
  final Map<int, Map<String, TextEditingController>> _c = {};
  int _ver = 0;

  TextEditingController _ctl(int id, String k, dynamic v) => (_c[id] ??= {})[k] ??= TextEditingController(text: v?.toString() ?? '');

  double? _hitung(int id) {
    final v = ['nilai_kehadiran', 'nilai_tugas', 'nilai_uts', 'nilai_uas'].map((k) => double.tryParse(_c[id]?[k]?.text ?? '')).toList();
    if (v.any((x) => x == null)) return null;
    return .1 * v[0]! + .2 * v[1]! + .3 * v[2]! + .4 * v[3]!;
  }

  String _huruf(double a) {
    for (final e in [(85, 'A'), (80, 'A-'), (75, 'B+'), (70, 'B'), (65, 'B-'), (60, 'C+'), (55, 'C'), (40, 'D')]) {
      if (a >= e.$1) return e.$2;
    }
    return 'E';
  }

  @override
  Widget build(BuildContext context) {
    final kid = widget.kelas['id'];
    final terkunci = widget.kelas['nilai_terkunci'] == true;
    return AsyncView<List>(
      key: ValueKey(_ver),
      load: () async => (await Api.I.get('/api/akademik/kelas/$kid/peserta')) as List,
      builder: (c, peserta, reload) {
        final aktif = peserta.where((p) => p['status'] == 'disetujui').toList();
        return ListView(padding: const EdgeInsets.all(16), children: [
          if (terkunci) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: const Row(children: [Icon(Icons.lock_rounded, color: AppColors.warning), SizedBox(width: 8), Expanded(child: Text('Nilai kelas ini telah dikunci oleh admin.', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)))])),
          Row(children: [
            Expanded(child: Text('${aktif.length} mahasiswa · Bobot: Kehadiran 10% · Tugas 20% · UTS 30% · UAS 40%', style: const TextStyle(fontSize: 11.5, color: AppColors.muted))),
            if (!terkunci) TextButton.icon(onPressed: () async {
              if (await konfirmasi(context, 'Isi Kehadiran', 'Nilai kehadiran akan diganti dengan persentase presensi. Lanjutkan?')) {
                if (await runAction(context, () => Api.I.post('/api/akademik/nilai/kelas/$kid/isi-kehadiran'), sukses: 'Kehadiran diisi dari presensi')) { _c.clear(); setState(() => _ver++); }
              }
            }, icon: const Icon(Icons.sync_rounded, size: 16), label: const Text('Dari presensi', style: TextStyle(fontSize: 12))),
          ]),
          const SizedBox(height: 8),
          if (aktif.isEmpty) const EmptyState('Belum ada peserta disetujui.'),
          ...aktif.map((p) {
            final id = p['id'] as int;
            return StatefulBuilder(builder: (ctx, setRow) {
              final akhir = _hitung(id);
              return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Avatar(p['mahasiswa_nama'][0], size: 36), const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p['mahasiswa_nama'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)), Text('${p['nim']} · Presensi ${p['persentase_kehadiran'] ?? '-'}%', style: const TextStyle(fontSize: 11.5, color: AppColors.muted))])),
                  Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(akhir == null ? '-' : _huruf(akhir), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 15)), if (akhir != null) Text(akhir.toStringAsFixed(1), style: const TextStyle(fontSize: 9, color: AppColors.muted))])),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  for (final e in [('nilai_kehadiran', 'Hadir'), ('nilai_tugas', 'Tugas'), ('nilai_uts', 'UTS'), ('nilai_uas', 'UAS')])
                    Expanded(child: Padding(padding: const EdgeInsets.only(right: 6), child: TextField(
                      controller: _ctl(id, e.$1, p[e.$1]), enabled: !terkunci, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), onChanged: (_) => setRow(() {}),
                      decoration: InputDecoration(labelText: e.$2, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                    ))),
                ]),
              ])));
            });
          }),
          if (aktif.isNotEmpty && !terkunci) ...[
            const SizedBox(height: 6),
            FilledButton.icon(
              icon: const Icon(Icons.save_rounded), label: const Text('Simpan Nilai'),
              onPressed: () async {
                final body = aktif.map((p) {
                  final id = p['id'] as int;
                  double? g(String k) => double.tryParse(_c[id]?[k]?.text ?? '');
                  return {'krs_id': id, 'nilai_kehadiran': g('nilai_kehadiran'), 'nilai_tugas': g('nilai_tugas'), 'nilai_uts': g('nilai_uts'), 'nilai_uas': g('nilai_uas')};
                }).toList();
                if (await runAction(context, () => Api.I.put('/api/akademik/nilai/kelas/$kid', body: body), sukses: 'Nilai tersimpan')) { _c.clear(); setState(() => _ver++); }
              },
            ),
          ],
          const SizedBox(height: 24),
        ]);
      },
    );
  }
}

class _PresensiTab extends StatefulWidget {
  final Map kelas;
  const _PresensiTab(this.kelas);
  @override
  State<_PresensiTab> createState() => _PresensiTabState();
}

class _PresensiTabState extends State<_PresensiTab> {
  int _ver = 0;
  @override
  Widget build(BuildContext context) {
    final kid = widget.kelas['id'];
    return AsyncView<Map>(
      key: ValueKey(_ver),
      load: () async => (await Api.I.get('/api/akademik/presensi/kelas/$kid/rekap')) as Map,
      builder: (c, d, reload) {
        final pertemuan = d['pertemuan'] as List, peserta = d['peserta'] as List;
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primary, foregroundColor: Colors.white, icon: const Icon(Icons.add_rounded), label: Text('Pertemuan ${pertemuan.length + 1}'),
            onPressed: () async {
              final materi = await inputDialog(context, 'Pertemuan ke-${pertemuan.length + 1}', label: 'Materi / topik', maxLines: 2);
              if (materi == null || !context.mounted) return;
              Map? p;
              if (await runAction(context, () async => p = await Api.I.post('/api/akademik/presensi/kelas/$kid/pertemuan', body: {'materi': materi}), sukses: 'Pertemuan dibuat, semua ditandai hadir')) {
                setState(() => _ver++);
                if (p != null && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => DsnPresensiForm(pertemuan: p!, peserta: peserta.map((x) => x['krs'] as Map).toList()))).then((_) => setState(() => _ver++));
              }
            },
          ),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            SectionCard(
              title: 'Pertemuan (${pertemuan.length}/16)', padding: EdgeInsets.zero,
              child: pertemuan.isEmpty ? const EmptyState('Belum ada pertemuan.') : Column(children: pertemuan.map((p) => ListTile(
                leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: .1), child: Text('${p['pertemuan_ke']}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary))),
                title: Text(p['materi'] ?? 'Materi belum diisi', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text('${tanggal(p['tanggal'])} · ${p['metode']} · Hadir ${p['jumlah_hadir']}/${peserta.length}', style: const TextStyle(fontSize: 11.5)),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DsnPresensiForm(pertemuan: p, peserta: peserta.map((x) => x['krs'] as Map).toList()))).then((_) => setState(() => _ver++)),
              )).toList()),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Rekap Kehadiran', padding: const EdgeInsets.all(12),
              child: peserta.isEmpty ? const EmptyState('Belum ada peserta.') : SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
                columnSpacing: 10, horizontalMargin: 4, headingRowHeight: 34, dataRowMinHeight: 40, dataRowMaxHeight: 48,
                columns: [const DataColumn(label: Text('Mahasiswa', style: TextStyle(fontSize: 11))), ...pertemuan.map((p) => DataColumn(label: Text('${p['pertemuan_ke']}', style: const TextStyle(fontSize: 11)))), const DataColumn(label: Text('%', style: TextStyle(fontSize: 11)))],
                rows: peserta.map((r) {
                  final k = r['krs'], pr = r['presensi'] as Map;
                  return DataRow(cells: [
                    DataCell(SizedBox(width: 120, child: Text(k['mahasiswa_nama'], style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))),
                    ...pertemuan.map((p) {
                      final s = pr['${p['id']}'];
                      return DataCell(Center(child: Container(width: 22, height: 22, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.status(s).withValues(alpha: .15), borderRadius: BorderRadius.circular(6)), child: Text(s == null ? '-' : s[0].toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.status(s))))));
                    }),
                    DataCell(Text('${k['persentase_kehadiran'] ?? '-'}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                  ]);
                }).toList(),
              )),
            ),
            const SizedBox(height: 80),
          ]),
        );
      },
    );
  }
}

class DsnPresensiForm extends StatefulWidget {
  final Map pertemuan;
  final List<Map> peserta;
  const DsnPresensiForm({super.key, required this.pertemuan, required this.peserta});
  @override
  State<DsnPresensiForm> createState() => _DsnPresensiFormState();
}

class _DsnPresensiFormState extends State<DsnPresensiForm> {
  final Map<int, String> _status = {};
  late final TextEditingController _materi = TextEditingController(text: widget.pertemuan['materi']);
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Api.I.get('/api/akademik/presensi/pertemuan/${widget.pertemuan['id']}').then((d) {
      for (final p in (d['presensi'] as List)) {
        _status[p['mahasiswa_id']] = p['status'];
      }
      if (mounted) setState(() => _loaded = true);
    }).catchError((_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    const opsi = [('hadir', 'H', AppColors.success), ('izin', 'I', AppColors.info), ('sakit', 'S', AppColors.muted), ('alpa', 'A', AppColors.danger)];
    return Scaffold(
      appBar: AppBar(title: Text('Presensi Pertemuan ${widget.pertemuan['pertemuan_ke']}'), actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.done_all_rounded), tooltip: 'Tandai semua',
          onSelected: (s) => setState(() { for (final p in widget.peserta) { _status[p['mahasiswa_id']] = s; } }),
          itemBuilder: (_) => opsi.map((o) => PopupMenuItem(value: o.$1, child: Text('Semua ${o.$1}'))).toList(),
        ),
      ]),
      body: !_loaded ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _materi, decoration: const InputDecoration(labelText: 'Materi / topik')),
        const SizedBox(height: 12),
        ...widget.peserta.map((p) {
          final id = p['mahasiswa_id'] as int;
          final cur = _status[id] ?? 'hadir';
          return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p['mahasiswa_nama'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text(p['nim'], style: const TextStyle(fontSize: 11, color: AppColors.muted))])),
            ...opsi.map((o) => Padding(padding: const EdgeInsets.only(left: 4), child: InkWell(
              onTap: () => setState(() => _status[id] = o.$1), borderRadius: BorderRadius.circular(8),
              child: Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: cur == o.$1 ? o.$3 : o.$3.withValues(alpha: .1), borderRadius: BorderRadius.circular(8)), child: Text(o.$2, style: TextStyle(fontWeight: FontWeight.w800, color: cur == o.$1 ? Colors.white : o.$3))),
            ))),
          ])));
        }),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.save_rounded), label: const Text('Simpan Presensi'),
          onPressed: () async {
            if (await runAction(context, () => Api.I.put('/api/akademik/presensi/pertemuan/${widget.pertemuan['id']}', body: {
              'materi': _materi.text, 'daftar': widget.peserta.map((p) => {'mahasiswa_id': p['mahasiswa_id'], 'status': _status[p['mahasiswa_id']] ?? 'hadir'}).toList(),
            }), sukses: 'Presensi tersimpan') && context.mounted) Navigator.pop(context);
          },
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: BorderSide(color: AppColors.danger.withValues(alpha: .4))),
          icon: const Icon(Icons.delete_outline_rounded), label: const Text('Hapus Pertemuan'),
          onPressed: () async {
            if (await konfirmasi(context, 'Hapus Pertemuan', 'Hapus pertemuan ini beserta presensinya?', bahaya: true) && context.mounted) {
              if (await runAction(context, () => Api.I.delete('/api/akademik/presensi/pertemuan/${widget.pertemuan['id']}'), sukses: 'Pertemuan dihapus') && context.mounted) Navigator.pop(context);
            }
          },
        ),
      ]),
    );
  }
}

// =============================================================== BIMBINGAN
class DsnBimbinganList extends StatelessWidget {
  const DsnBimbinganList({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Bimbingan Tesis')),
        body: AsyncView<List>(
          load: () async => (await Api.I.get('/api/tesis/bimbingan')) as List,
          builder: (c, d, _) => ListView(padding: const EdgeInsets.all(16), children: d.isEmpty ? const [EmptyState('Belum ada mahasiswa bimbingan.')] : d.map((t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(child: InkWell(
            borderRadius: BorderRadius.circular(18), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DsnBimbinganDetail(tesisId: t['id']))),
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Avatar(t['mahasiswa_nama'][0], size: 38), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t['mahasiswa_nama'], style: const TextStyle(fontWeight: FontWeight.w700)), Text('${t['nim']} · ${t['prodi']}', style: const TextStyle(fontSize: 11.5, color: AppColors.muted))])), StatusBadge(t['status'])]),
              const SizedBox(height: 10),
              Text(t['judul'], style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              ProgressBar((t['progres'] ?? 0) / 100),
              const SizedBox(height: 4),
              Text('${t['progres']}% · ${t['jumlah_bimbingan_disetujui']} bimbingan disetujui', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            ])),
          )))).toList()),
        ),
      );
}

class DsnBimbinganDetail extends StatefulWidget {
  final int tesisId;
  const DsnBimbinganDetail({super.key, required this.tesisId});
  @override
  State<DsnBimbinganDetail> createState() => _DsnBimbinganDetailState();
}

class _DsnBimbinganDetailState extends State<DsnBimbinganDetail> {
  int _ver = 0;
  void _refresh() => setState(() => _ver++);

  Future<void> _review(Map b, String status) async {
    final cat = await inputDialog(context, status == 'disetujui' ? 'Setujui Bimbingan' : 'Minta Revisi', label: 'Catatan / arahan untuk mahasiswa');
    if (cat == null || !mounted) return;
    if (await runAction(context, () => Api.I.patch('/api/tesis/bimbingan/log/${b['id']}', body: {'status': status, 'catatan_dosen': cat}), sukses: 'Log diperbarui')) _refresh();
  }

  Future<void> _catat() async {
    final topik = TextEditingController(), cat = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Catat Bimbingan'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: topik, decoration: const InputDecoration(labelText: 'Topik')), const SizedBox(height: 10), TextField(controller: cat, decoration: const InputDecoration(labelText: 'Catatan / arahan'), maxLines: 3)]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('Simpan'))],
    ));
    if (ok != true || !mounted) return;
    if (await runAction(context, () => Api.I.post('/api/tesis/bimbingan/${widget.tesisId}/log', body: {'topik': topik.text, 'catatan_dosen': cat.text}), sukses: 'Catatan ditambahkan')) _refresh();
  }

  Future<void> _tahapan(Map t) async {
    const opsi = ['disetujui', 'proposal', 'penelitian', 'seminar hasil', 'ujian', 'ditolak'];
    String sel = opsi.contains(t['status']) ? t['status'] : 'disetujui';
    final cat = TextEditingController(text: t['catatan']);
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, setS) => AlertDialog(
      title: const Text('Perbarui Tahapan'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: sel, items: opsi.map((o) => DropdownMenuItem(value: o, child: Text(cap(o)))).toList(), onChanged: (v) => setS(() => sel = v!), decoration: const InputDecoration(labelText: 'Tahapan')),
        const SizedBox(height: 10),
        TextField(controller: cat, decoration: const InputDecoration(labelText: 'Catatan untuk mahasiswa'), maxLines: 3),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('Simpan'))],
    )));
    if (ok != true || !mounted) return;
    if (await runAction(context, () => Api.I.patch('/api/tesis/bimbingan/${widget.tesisId}/status', body: {'status': sel, 'catatan': cat.text}), sukses: 'Tahapan diperbarui')) _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Detail Bimbingan')),
        floatingActionButton: FloatingActionButton.extended(onPressed: _catat, backgroundColor: AppColors.primary, foregroundColor: Colors.white, icon: const Icon(Icons.add_comment_outlined), label: const Text('Catat Bimbingan')),
        body: AsyncView<Map>(
          key: ValueKey(_ver),
          load: () async => (await Api.I.get('/api/tesis/bimbingan/${widget.tesisId}')) as Map,
          builder: (c, t, _) {
            return AsyncView<Map>(
              load: () async => (await Api.I.get('/api/akademik/dosen/me')) as Map,
              builder: (c, me, _) {
                final sayaP1 = me['id'] == t['pembimbing1_id'];
                final bimb = (t['bimbingan'] ?? []) as List;
                return ListView(padding: const EdgeInsets.all(16), children: [
                  Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Avatar(t['mahasiswa_nama'][0], size: 44), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t['mahasiswa_nama'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), Text('${t['nim']} · ${t['prodi']}', style: const TextStyle(fontSize: 12, color: AppColors.muted))])), StatusBadge(t['status'])]),
                    const Divider(height: 24),
                    Text(t['judul'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(t['abstrak'] ?? '-', style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.5)),
                    const SizedBox(height: 10),
                    ProgressBar((t['progres'] ?? 0) / 100),
                    const SizedBox(height: 10),
                    InfoRow('Pembimbing 1', '${t['pembimbing1_nama'] ?? '-'}${sayaP1 ? ' (Anda)' : ''}'),
                    InfoRow('Pembimbing 2', '${t['pembimbing2_nama'] ?? '-'}${me['id'] == t['pembimbing2_id'] ? ' (Anda)' : ''}'),
                    if (sayaP1) ...[const SizedBox(height: 10), OutlinedButton.icon(onPressed: () => _tahapan(t), icon: const Icon(Icons.flag_outlined), label: const Text('Perbarui Tahapan (P1)'))],
                  ]))),
                  const SizedBox(height: 12),
                  SectionCard(title: 'Log Bimbingan (${bimb.length})', child: bimb.isEmpty ? const Text('Belum ada bimbingan.', style: TextStyle(color: AppColors.muted)) : Column(children: bimb.map((b) => BimbinganItem(b,
                      action: b['dosen_id'] == me['id'] && b['status'] == 'menunggu' ? Row(children: [
                        Expanded(child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(38), backgroundColor: AppColors.success), onPressed: () => _review(b, 'disetujui'), child: const Text('Setujui'))),
                        const SizedBox(width: 8),
                        Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(38), foregroundColor: AppColors.warning, side: const BorderSide(color: AppColors.warning)), onPressed: () => _review(b, 'revisi'), child: const Text('Revisi'))),
                      ]) : null)).toList())),
                  const SizedBox(height: 80),
                ]);
              },
            );
          },
        ),
      );
}

// =============================================================== PERWALIAN
class DsnPerwalian extends StatelessWidget {
  const DsnPerwalian({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Perwalian Akademik')),
        body: AsyncView<Map>(
          load: () async => (await Api.I.get('/api/akademik/dosen/me/perwalian')) as Map,
          builder: (c, d, reload) {
            final mhs = d['mahasiswa'] as List, krs = d['krs_menunggu'] as List;
            return ListView(padding: const EdgeInsets.all(16), children: [
              SectionCard(
                title: 'KRS Menunggu Persetujuan', padding: EdgeInsets.zero,
                trailing: krs.isEmpty ? null : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(50)), child: Text('${krs.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
                child: krs.isEmpty ? const EmptyState('Tidak ada KRS yang menunggu.', icon: Icons.check_circle_outline_rounded) : Column(children: krs.map((k) => Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${k['mahasiswa_nama']} (${k['nim']})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text('${k['nama_mk']} · ${k['sks']} SKS · ${k['hari'] ?? '-'} ${k['jam_mulai'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(36), backgroundColor: AppColors.success), onPressed: () async { if (await runAction(context, () => Api.I.post('/api/akademik/krs/${k['id']}/setujui', body: {}), sukses: 'KRS disetujui')) reload(); }, child: const Text('Setujui'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(36), foregroundColor: AppColors.danger, side: BorderSide(color: AppColors.danger.withValues(alpha: .5))), onPressed: () async {
                      final cat = await inputDialog(context, 'Tolak KRS', label: 'Alasan');
                      if (cat == null || !context.mounted) return;
                      if (await runAction(context, () => Api.I.post('/api/akademik/krs/${k['id']}/tolak', body: {'catatan': cat}), sukses: 'KRS ditolak')) reload();
                    }, child: const Text('Tolak'))),
                  ]),
                  const Divider(height: 20),
                ]))).toList()),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Mahasiswa PA (${mhs.length})', padding: EdgeInsets.zero,
                child: mhs.isEmpty ? const EmptyState('Belum ada mahasiswa PA.') : Column(children: mhs.map((m) => ListTile(
                  leading: Avatar(m['nama'][0], size: 38),
                  title: Text(m['nama'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text('${m['nim']} · Smt ${m['semester_ke']} · ${m['total_sks']} SKS · IPK ${num2(m['ipk'])}', style: const TextStyle(fontSize: 11.5)),
                  trailing: StatusBadge(m['status']),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MhsTranskrip(mahasiswaId: m['id']))),
                )).toList()),
              ),
            ]);
          },
        ),
      );
}
