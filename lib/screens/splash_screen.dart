import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:page_transition/page_transition.dart';
import 'package:gemini_ai/screens/chatScreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _glowAnim;
  bool _showLoader = false;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleAnim = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _logoController.forward();

    Future.delayed(const Duration(milliseconds: 800), () {
      _textController.forward();
      setState(() => _showLoader = true);
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageTransition(
            type: PageTransitionType.fade,
            duration: const Duration(milliseconds: 600),
            child: const ChatScreen(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      body: Stack(
        children: [
          // Background ambient glow
          Positioned(
            top: -100,
            left: -80,
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Opacity(
                opacity: _glowAnim.value * 0.3,
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFF6C63FF), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -80,
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Opacity(
                opacity: (1 - _glowAnim.value) * 0.3,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFF00D4AA), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo mark
                ScaleTransition(
                  scale: _scaleAnim,
                  child: AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (_, child) => Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF)
                                .withOpacity(0.4 * _glowAnim.value),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(_fadeAnim),
                    child: Column(
                      children: [
                        Text(
                          'Gemini AI',
                          style: GoogleFonts.dmSans(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your intelligent chat companion',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.35),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 64),

                // Loader
                if (_showLoader)
                  SpinKitThreeBounce(
                    color: const Color(0xFF6C63FF).withOpacity(0.7),
                    size: 28,
                  ),
              ],
            ),
          ),

          // Version tag
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Text(
                'v2.0',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}