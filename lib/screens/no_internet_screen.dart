import 'package:flutter/material.dart';

class NoInternetScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const NoInternetScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Lost'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onBackground,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 100,
              color: isDarkMode ? Colors.blueGrey[400] : Colors.blueGrey[600],
            ),
            const SizedBox(height: 24),
            Text(
              'No Internet Connection',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onBackground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Please check your network connection and try again',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.tonal(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: isDarkMode 
                    ? Colors.blueGrey[800] 
                    : Colors.blueGrey[100],
                foregroundColor: isDarkMode 
                    ? Colors.blueGrey[100] 
                    : Colors.blueGrey[800],
                minimumSize: const Size(200, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Retry Connection',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Try again',
                style: TextStyle(
                  color: isDarkMode 
                      ? Colors.blueGrey[300] 
                      : Colors.blueGrey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}