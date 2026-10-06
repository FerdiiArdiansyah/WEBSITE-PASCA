import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Menampilkan dokumen surat persis seperti struktur JSON `/persuratan/.../dokumen` dari server.
/// Widget ini tidak merakit kalimat sendiri; seluruh teks berasal dari backend.
class SuratDokumenView extends StatelessWidget {
  final Map d;
  const SuratDokumenView(this.d, {super.key});

  @override
  Widget build(BuildContext context) {
    final kop = d['kop'] as Map, ttd = d['penandatangan'] as Map;
    final data = (d['data'] as List).cast<List>(), isi = (d['isi'] as List).cast<String>();
    const body = TextStyle(fontSize: 13, height: 1.6, color: Colors.black87);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE3E6F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Text(kop['universitas'].toString().toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black)),
          Text(kop['institusi'].toString().toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black)),
          Text('${kop['alamat']} · Telp. ${kop['telepon']} · ${kop['email']}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        ]),
        const Divider(thickness: 2, color: Colors.black, height: 22),
        Center(child: Column(children: [
          Text(d['judul'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, decoration: TextDecoration.underline, color: Colors.black)),
          Text(d['nomor'], style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ])),
        const SizedBox(height: 16),
        Text(d['pembuka'], style: body),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.only(left: 18), child: Column(children: data.map((r) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Text(r[0].toString(), style: body)),
          const Text(':  ', style: body),
          Expanded(child: Text(r[1].toString(), style: body)),
        ])).toList())),
        const SizedBox(height: 10),
        ...isi.map((p) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(p, style: body, textAlign: TextAlign.justify))),
        const SizedBox(height: 18),
        Align(alignment: Alignment.centerRight, child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(d['tanggal_hijriah'], style: body),
          Text(d['tanggal_masehi'], style: body),
          const SizedBox(height: 6),
          Text(ttd['jabatan'], style: body),
          const SizedBox(height: 44),
          Text(ttd['nama'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, color: Colors.black)),
          Text(ttd['nbm'], style: body),
        ])),
        if (d['final'] != true) Padding(padding: const EdgeInsets.only(top: 14), child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
          child: const Text('PRATINJAU — nomor & tanggal surat ditetapkan admin saat disetujui.', style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        )),
      ]),
    );
  }
}
