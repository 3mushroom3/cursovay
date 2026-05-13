import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'src/app.dart';
import 'src/auth_service.dart';
import 'src/theme_notifier.dart';

Future<void> _activateAppCheck() async {
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleAppAttestProvider(),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _activateAppCheck();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, themeNotifier, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: themeNotifier.mode,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            home: const App(),
          );
        },
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  const accent = Color(0xFF1370B9);
  final isDark = brightness == Brightness.dark;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: accent,
    primary: accent,
    brightness: brightness,
    surface: isDark ? const Color(0xFF1E1E1E) : Colors.white,
  );

  final textTheme = GoogleFonts.nunitoTextTheme(
    ThemeData(brightness: brightness).textTheme,
  ).copyWith(
    displayLarge: GoogleFonts.nunito(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: isDark ? Colors.white : const Color(0xFF0D1B2A),
    ),
    titleLarge: GoogleFonts.nunito(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: isDark ? Colors.white : const Color(0xFF0D1B2A),
    ),
    titleMedium: GoogleFonts.nunito(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white70 : const Color(0xFF1C3A5E),
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      foregroundColor: isDark ? Colors.white : Colors.black,
      elevation: 0,
      titleTextStyle: GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : const Color(0xFF0D1B2A),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      indicatorColor: accent.withValues(alpha: 0.15),
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.nunito(
          color: isDark ? Colors.white70 : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: ChipThemeData(
      selectedColor: accent.withValues(alpha: 0.2),
      labelStyle: GoogleFonts.nunito(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 13,
      ),
    ),
  );
}
