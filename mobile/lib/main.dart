import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/session.dart';
import 'core/theme.dart';
import 'screens/admin_screens.dart';
import 'screens/auth_screens.dart';
import 'screens/dosen_screens.dart';
import 'screens/mahasiswa_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  Session.I.restore();
  runApp(const SiakadApp());
}

class SiakadApp extends StatelessWidget {
  const SiakadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIAKAD Pascasarjana Unismuh Makassar',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      // Batasi skala teks agar tata letak tetap konsisten pada perangkat dengan font besar.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(MediaQuery.of(context).textScaler.scale(1).clamp(0.9, 1.1))),
        child: child!,
      ),
      home: ListenableBuilder(
        listenable: Session.I,
        builder: (context, _) {
          if (Session.I.loading) return const SplashScreen();
          final u = Session.I.user;
          if (u == null) return const LoginScreen();
          switch (u.role) {
            case 'admin':
              return const AdminShell();
            case 'dosen':
              return const DosenShell();
            default:
              return const MahasiswaShell();
          }
        },
      ),
    );
  }
}
