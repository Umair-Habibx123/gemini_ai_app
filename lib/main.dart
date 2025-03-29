import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:provider/provider.dart';
import 'services/connectivity_service.dart';
import 'screens/splash_screen.dart';
import 'screens/no_internet_screen.dart';

String? apiKey; // Global variable for API key

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  apiKey = dotenv.env['API_KEY'];

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
          home:
              connectivityService.hasInternet
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
