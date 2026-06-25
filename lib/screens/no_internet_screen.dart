import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class NoInternetScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final bool isChecking;

  const NoInternetScreen({
    super.key,
    required this.onRetry,
    this.isChecking = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: c.border),
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 36,
                  color: c.textFaint,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'No Connection',
                style: GoogleFonts.dmSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "You're offline. Check your Wi-Fi or mobile data\nand we'll reconnect automatically.",
                style: GoogleFonts.dmSans(fontSize: 14, color: c.textFaint),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: isChecking ? null : onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: c.brandGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: c.primary.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isChecking) ...[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        isChecking ? 'Checking…' : 'Try Again',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
