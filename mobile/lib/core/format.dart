import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api.dart';

final _rp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
String rupiah(num? v) => _rp.format(v ?? 0);

String tanggal(dynamic v, {bool withTime = false}) {
  if (v == null || v.toString().isEmpty) return '-';
  final d = v is DateTime ? v : DateTime.tryParse(v.toString());
  if (d == null) return v.toString();
  return DateFormat(withTime ? 'd MMM yyyy HH:mm' : 'd MMM yyyy', 'id_ID').format(d);
}

String cap(String? s) => (s == null || s.isEmpty) ? '-' : s[0].toUpperCase() + s.substring(1);

String num2(num? v) => v == null ? '-' : v.toStringAsFixed(2);

String hariIni() => DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());

/// Jalankan aksi API dengan umpan balik snackbar; kembalikan true jika sukses.
Future<bool> runAction(BuildContext context, Future<void> Function() fn, {String? sukses}) async {
  try {
    await fn();
    if (context.mounted && sukses != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(sukses), backgroundColor: const Color(0xFF065F46)));
    }
    return true;
  } on ApiException catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: const Color(0xFF9F1239)));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal terhubung ke server: $e'), backgroundColor: const Color(0xFF9F1239)));
  }
  return false;
}

Future<bool> konfirmasi(BuildContext context, String judul, String pesan, {String ya = 'Ya, lanjutkan', bool bahaya = false}) async {
  return await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(judul),
          content: Text(pesan),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
            FilledButton(
              style: bahaya ? FilledButton.styleFrom(backgroundColor: const Color(0xFFF43F5E), minimumSize: const Size(0, 44)) : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(c, true),
              child: Text(ya),
            ),
          ],
        ),
      ) ??
      false;
}

Future<String?> inputDialog(BuildContext context, String judul, {String label = 'Catatan', String? awal, int maxLines = 2}) async {
  final c = TextEditingController(text: awal);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(judul),
      content: TextField(controller: c, maxLines: maxLines, decoration: InputDecoration(labelText: label), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Simpan')),
      ],
    ),
  );
}
