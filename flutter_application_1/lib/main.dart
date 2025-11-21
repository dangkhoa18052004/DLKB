import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/auth/login_screen.dart'; // Đã thêm
import 'screens/customer/home_screen.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('vi');

  final apiService = ApiService();
  final authService = AuthService(apiService);

  await authService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
      ],
      child: const HospitalBookingApp(),
    ),
  );
}

class HospitalBookingApp extends StatelessWidget {
  const HospitalBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return MaterialApp(
      title: 'Bệnh viện Nhi Đồng II',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          secondary: const Color(0xFFFF9800),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.robotoTextTheme(),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 4,
          backgroundColor: Color.fromARGB(255, 43, 155, 247),
          foregroundColor: Colors.white,
        ),
      ),
      home: Builder(
        builder: (context) {
          if (!authService.isInitialized) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }

          if (authService.isAuthenticated) {
            return const HomeScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
