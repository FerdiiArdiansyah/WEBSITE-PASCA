import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

/// Informasi publik: profil institusi, prodi, pengumuman, kalender, PMB.
class PublicScreen extends StatelessWidget {
  const PublicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AsyncView<Map>(
        load: () async => (await Api.I.get('/api/publik/beranda')) as Map,
        builder: (c, d, _) {
          final inst = d['institusi'] ?? {}, stat = d['statistik'] ?? {};
          final prodi = (d['prodi'] ?? []) as List, peng = (d['pengumuman'] ?? []) as List, kal = (d['kalender'] ?? []) as List;
          return CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 250, pinned: true, backgroundColor: AppColors.navy, foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(gradient: AppColors.gradNavy),
                  padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(50)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified_rounded, color: AppColors.gold, size: 14), SizedBox(width: 5), Text('Terakreditasi Unggul', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))])),
                    const SizedBox(height: 10),
                    Text(inst['nama'] ?? 'Program Pascasarjana', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                    Text(inst['universitas'] ?? '', style: const TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Program Magister (S2) & Doktor (S3) berorientasi riset, inovasi, dan nilai-nilai Islami.', style: TextStyle(color: Colors.white.withValues(alpha: .75), fontSize: 12)),
                  ]),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(delegate: SliverChildListDelegate([
                Row(children: [
                  Expanded(child: _Stat(Icons.account_tree_rounded, '${stat['prodi'] ?? 0}', 'Prodi')),
                  const SizedBox(width: 8),
                  Expanded(child: _Stat(Icons.badge_rounded, '${stat['dosen'] ?? 0}', 'Dosen')),
                  const SizedBox(width: 8),
                  Expanded(child: _Stat(Icons.groups_rounded, '${stat['mahasiswa'] ?? 0}', 'Mahasiswa')),
                  const SizedBox(width: 8),
                  Expanded(child: _Stat(Icons.school_rounded, '${stat['alumni'] ?? 0}', 'Alumni')),
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(gradient: AppColors.gradGold, borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Penerimaan Mahasiswa Baru', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy)),
                      Text('Daftar sekarang, seleksi berkala sepanjang tahun.', style: TextStyle(fontSize: 12, color: AppColors.navy)),
                    ])),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.navy, minimumSize: const Size(0, 42)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PmbScreen(prodi: prodi))),
                      child: const Text('Daftar'),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                _Title('Program Studi'),
                ...prodi.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(child: ListTile(
                    leading: Container(width: 44, height: 44, alignment: Alignment.center, decoration: BoxDecoration(color: (p['jenjang'] == 'S3' ? AppColors.danger : AppColors.primary).withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
                        child: Text(p['jenjang'], style: TextStyle(fontWeight: FontWeight.w800, color: p['jenjang'] == 'S3' ? AppColors.danger : AppColors.primary))),
                    title: Text(p['nama'], style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('Akreditasi ${p['akreditasi'] ?? '-'} · Gelar ${p['gelar'] ?? '-'} · ${rupiah(p['biaya_semester'])}/smt', style: const TextStyle(fontSize: 11.5)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProdiDetailScreen(p))),
                  )),
                )),
                const SizedBox(height: 12),
                _Title('Pengumuman'),
                if (peng.isEmpty) const EmptyState('Belum ada pengumuman.'),
                ...peng.map((p) => PengumumanTile(p)),
                const SizedBox(height: 12),
                _Title('Kalender Akademik'),
                if (kal.isEmpty) const EmptyState('Belum ada agenda.'),
                ...kal.take(6).map((k) => ListTile(
                  dense: true, contentPadding: EdgeInsets.zero,
                  leading: const IconBox(Icons.event_rounded, color: AppColors.sky),
                  title: Text(k['kegiatan'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text('${tanggal(k['tanggal_mulai'])}${k['tanggal_selesai'] != null ? ' – ${tanggal(k['tanggal_selesai'])}' : ''}', style: const TextStyle(fontSize: 11.5)),
                )),
                const SizedBox(height: 20),
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Kontak', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  _Kontak(Icons.location_on_outlined, inst['alamat'] ?? ''),
                  _Kontak(Icons.email_outlined, inst['email'] ?? ''),
                  _Kontak(Icons.phone_outlined, inst['telepon'] ?? ''),
                ]))),
                const SizedBox(height: 24),
              ])),
            ),
          ]);
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _Stat(this.icon, this.value, this.label);
  @override
  Widget build(BuildContext context) => Card(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [Icon(icon, color: AppColors.gold, size: 22), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.muted))]),
      ));
}

class _Title extends StatelessWidget {
  final String t;
  const _Title(this.t);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [Container(width: 4, height: 18, decoration: BoxDecoration(gradient: AppColors.gradPrimary, borderRadius: BorderRadius.circular(4))), const SizedBox(width: 10), Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))]),
      );
}

class _Kontak extends StatelessWidget {
  final IconData i;
  final String t;
  const _Kontak(this.i, this.t);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Icon(i, size: 16, color: AppColors.muted), const SizedBox(width: 8), Expanded(child: Text(t, style: const TextStyle(fontSize: 12.5)))]));
}

class PengumumanTile extends StatelessWidget {
  final Map p;
  const PengumumanTile(this.p, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => DraggableScrollableSheet(
              expand: false, initialChildSize: .6, builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(20, 0, 20, 30), children: [
                Row(children: [Chip(label: Text(p['kategori'] ?? 'Umum'), backgroundColor: AppColors.primary.withValues(alpha: .1), labelStyle: const TextStyle(fontSize: 11, color: AppColors.primary)), const Spacer(), Text(tanggal(p['created_at']), style: const TextStyle(color: AppColors.muted, fontSize: 12))]),
                const SizedBox(height: 8),
                Text(p['judul'], style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(p['isi'], style: const TextStyle(height: 1.5)),
              ]),
            )),
            child: Container(
              decoration: BoxDecoration(border: Border(left: BorderSide(color: p['penting'] == true ? AppColors.danger : AppColors.primary, width: 4)), borderRadius: BorderRadius.circular(18)),
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (p['penting'] == true) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.push_pin_rounded, size: 14, color: AppColors.danger)),
                  Expanded(child: Text(p['judul'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                ]),
                const SizedBox(height: 4),
                Text(p['isi'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 6),
                Text('${p['kategori'] ?? 'Umum'} · ${tanggal(p['created_at'])}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ]),
            ),
          ),
        ),
      );
}

class ProdiDetailScreen extends StatelessWidget {
  final Map p;
  const ProdiDetailScreen(this.p, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('${p['jenjang']} ${p['nama']}')),
        body: AsyncView<List>(
          load: () async => (await Api.I.get('/api/akademik/prodi/${p['id']}/kurikulum')) as List,
          builder: (c, mk, _) => ListView(padding: const EdgeInsets.all(16), children: [
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['deskripsi'] ?? '-', style: const TextStyle(height: 1.5)),
              const Divider(height: 24),
              InfoRow('Akreditasi', p['akreditasi'] ?? '-'),
              InfoRow('Gelar', p['gelar'] ?? '-'),
              InfoRow('Biaya / semester', rupiah(p['biaya_semester'])),
              InfoRow('Ketua Prodi', p['kaprodi_nama'] ?? '-'),
            ]))),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Struktur Kurikulum (${mk.fold<int>(0, (a, b) => a + (b['sks'] as int))} SKS)',
              padding: EdgeInsets.zero,
              child: Column(children: mk.map((m) => ListTile(
                dense: true,
                leading: CircleAvatar(radius: 16, backgroundColor: AppColors.primary.withValues(alpha: .1), child: Text('${m['semester_ke']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))),
                title: Text(m['nama'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text('${m['kode']} · ${m['sks']} SKS · ${cap(m['jenis'])}', style: const TextStyle(fontSize: 11.5)),
              )).toList()),
            ),
          ]),
        ),
      );
}

class PmbScreen extends StatefulWidget {
  final List prodi;
  const PmbScreen({super.key, required this.prodi});
  @override
  State<PmbScreen> createState() => _PmbScreenState();
}

class _PmbScreenState extends State<PmbScreen> {
  final _f = GlobalKey<FormState>();
  final nama = TextEditingController(), email = TextEditingController(), telp = TextEditingController(), pend = TextEditingController(), ipk = TextEditingController(), rencana = TextEditingController();
  int? prodiId;
  Map? hasil;

  @override
  Widget build(BuildContext context) {
    if (hasil != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pendaftaran Berhasil')),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 80),
          const SizedBox(height: 16),
          Text('Terima kasih, ${hasil!['nama']}!', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Pendaftaran Anda pada ${hasil!['prodi_nama']} telah kami terima.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 20),
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
            const Text('Nomor Pendaftaran', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            SelectableText(hasil!['nomor_pendaftaran'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text('Simpan nomor ini. Info seleksi dikirim ke ${hasil!['email']}.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]))),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Kembali')),
        ]))),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Pendaftaran Mahasiswa Baru')),
      body: Form(
        key: _f,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('Persyaratan', style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('• Ijazah & transkrip S1 (S2) / S2 (S3)\n• IPK minimal 3,00\n• Rencana penelitian singkat\n• Sertifikat TOEFL/IELTS\n• Surat rekomendasi akademik', style: TextStyle(fontSize: 12.5, height: 1.6)),
          ]))),
          const SizedBox(height: 14),
          TextFormField(controller: nama, decoration: const InputDecoration(labelText: 'Nama lengkap *'), validator: (v) => (v ?? '').length < 3 ? 'Wajib diisi' : null),
          const SizedBox(height: 10),
          TextFormField(controller: email, decoration: const InputDecoration(labelText: 'Email *'), keyboardType: TextInputType.emailAddress, validator: (v) => !(v ?? '').contains('@') ? 'Email tidak valid' : null),
          const SizedBox(height: 10),
          TextFormField(controller: telp, decoration: const InputDecoration(labelText: 'Telepon / WhatsApp *'), keyboardType: TextInputType.phone, validator: (v) => (v ?? '').length < 6 ? 'Wajib diisi' : null),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: prodiId, decoration: const InputDecoration(labelText: 'Program studi pilihan *'),
            items: widget.prodi.map((p) => DropdownMenuItem<int>(value: p['id'], child: Text('${p['jenjang']} ${p['nama']}'))).toList(),
            onChanged: (v) => setState(() => prodiId = v), validator: (v) => v == null ? 'Pilih prodi' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(controller: pend, decoration: const InputDecoration(labelText: 'Pendidikan terakhir *', hintText: 'S1 Pendidikan Matematika, Universitas ...'), validator: (v) => (v ?? '').length < 3 ? 'Wajib diisi' : null),
          const SizedBox(height: 10),
          TextFormField(controller: ipk, decoration: const InputDecoration(labelText: 'IPK terakhir'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 10),
          TextFormField(controller: rencana, decoration: const InputDecoration(labelText: 'Rencana penelitian (ringkas)'), maxLines: 4),
          const SizedBox(height: 18),
          FilledButton.icon(
            icon: const Icon(Icons.send_rounded), label: const Text('Kirim Pendaftaran'),
            onPressed: () async {
              if (!_f.currentState!.validate()) return;
              await runAction(context, () async {
                final r = await Api.I.post('/api/layanan/pmb/daftar', body: {
                  'nama': nama.text, 'email': email.text, 'telepon': telp.text, 'prodi_id': prodiId, 'pendidikan_terakhir': pend.text,
                  'ipk_terakhir': double.tryParse(ipk.text.replaceAll(',', '.')), 'rencana_penelitian': rencana.text,
                });
                setState(() => hasil = r);
              });
            },
          ),
        ]),
      ),
    );
  }
}
