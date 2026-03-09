import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:provider/provider.dart';
import 'services/connectivity_service.dart';
import 'screens/splash_screen.dart';
import 'screens/no_internet_screen.dart';

String? apiKey;
String? geminiModel;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  apiKey = dotenv.env['API_KEY'];
  geminiModel = dotenv.env['GEMINI_MODEL'] ?? 'gemini-3.1-pro-preview';

  assert(apiKey != null && apiKey!.isNotEmpty, 'API_KEY is missing from .env');

  runApp(
    ChangeNotifierProvider(
      create: (context) => ConnectivityService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivityService, child) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            scaffoldBackgroundColor: const Color(0xFF0A0A12),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6C63FF),
              secondary: Color(0xFF00D4AA),
            ),
          ),
          home: connectivityService.hasInternet
              ? const SplashScreen()
              : NoInternetScreen(
                  onRetry: connectivityService.retryConnection,
                ),
          builder: (context, child) {
            return Stack(
              children: [
                child!,
                if (!connectivityService.hasInternet)
                  NoInternetScreen(
                    onRetry: connectivityService.retryConnection,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}