import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'services/connectivity_service.dart';
import 'screens/splash_screen.dart';
import 'screens/no_internet_screen.dart';
import 'theme/app_theme.dart';

String? apiKey;
String? geminiModel; // currently active model (for display)
List<String> geminiModels = []; // full fallback chain

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  apiKey = dotenv.env['API_KEY'];

  final modelsRaw = dotenv.env['GEMINI_MODELS'] ?? 'gemini-2.0-flash';
  geminiModels =
      modelsRaw
          .split(',')
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty)
          .toList();
  geminiModel = geminiModels.first; // default display model

  assert(apiKey != null && apiKey!.isNotEmpty, 'API_KEY is missing from .env');
  assert(geminiModels.isNotEmpty, 'GEMINI_MODELS is missing from .env');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final connectivity = context.watch<ConnectivityService>();

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.mode,
      home: const SplashScreen(),
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            if (!connectivity.hasInternet)
              NoInternetScreen(
                onRetry: connectivity.retryConnection,
                isChecking: connectivity.isChecking,
              ),
          ],
        );
      },
    );
  }
}
