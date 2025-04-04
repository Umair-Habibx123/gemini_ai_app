import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InputArea extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onPickImage;
  final VoidCallback onSendMessage;

  const InputArea({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onPickImage,
    required this.onSendMessage,
  });

  @override
  State<InputArea> createState() => _InputAreaState();
}

class _InputAreaState extends State<InputArea> {
  final FocusNode _focusNode = FocusNode();
  double inputHeight = 50.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_adjustHeight);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_adjustHeight);
    _focusNode.dispose();
    super.dispose();
  }

  void _adjustHeight() {
    final textLength = widget.controller.text.length;
    setState(() {
      inputHeight = (textLength > 40) ? 120.0 : 50.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
         border: Border.all( // Add 2px border
      color: Colors.grey[300]!, // Border color (light grey)
      width: 2.0, // 2px thickness
    ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image Picker Button
          GestureDetector(
            onTap: widget.isLoading ? null : widget.onPickImage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.image,
                color: Colors.blueAccent,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Chat Input Field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 50, maxHeight: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: widget.controller,
                maxLines: null,
                focusNode: _focusNode,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  border: InputBorder.none,
                ),
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Send Button
          GestureDetector(
            onTap: widget.isLoading ? null : widget.onSendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child:
                  widget.isLoading
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                      : const Icon(Icons.send, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
