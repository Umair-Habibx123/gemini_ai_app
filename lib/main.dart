import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'screens/splash_screen.dart';

String? apiKey; // Define a global variable to hold the API key

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  apiKey = dotenv.env['API_KEY'];

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final Connectivity _connectivity = Connectivity();
  late Stream<List<ConnectivityResult>> _connectivityStream;

  @override
  void initState() {
    super.initState();
    _connectivityStream = _connectivity.onConnectivityChanged;
    _monitorConnectivity();
  }

  void _monitorConnectivity() {
    _connectivityStream.listen((List<ConnectivityResult> results) {
     
      if (results.every((result) => result == ConnectivityResult.none)) {
        _showNoConnectionDialog();
      }
    });
  }

  void _showNoConnectionDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('No Internet Connection'),
        content: const Text(
          'Please check your internet connection and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const GetMaterialApp(
      home: SplashScreen(),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
