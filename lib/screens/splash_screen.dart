import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
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
  bool _showProgressIndicator = false;
  late AnimationController _logoController;
  late Animation<double> _logoAnimation;
  late AnimationController _textController;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOutCubic,
    );

    _textController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _textAnimation = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    );

    _logoController.forward();

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _showProgressIndicator = true;
        _textController.forward();
      });
    });

    Future.delayed(const Duration(seconds: 4), () {
      Navigator.pushReplacement(
        context,
        PageTransition(
          type: PageTransitionType.fade,
          child: const ChatScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var width = Get.width;
    var height = Get.height;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _logoAnimation,
              child: Image.asset(
                'assets/images/app_logo.png',
                width: width * 0.4,
                height: height * 0.4,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.error,
                    size: width * 0.3,
                    color: Colors.redAccent,
                  );
                },
              ),
            ),
            const SizedBox(height: 25),
            FadeTransition(
              opacity: _textAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  "Gemini AI - Your Intelligent Chat Companion",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        blurRadius: 8.0,
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(2.0, 3.0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            if (_showProgressIndicator)
              const SpinKitThreeBounce(
                color: Colors.white,
                size: 50,
              ),
          ],
        ),
      ),
    );
  }
}
