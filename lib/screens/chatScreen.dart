import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gemini_ai/DB/SQLiteHelper.dart';
import 'package:gemini_ai/main.dart';
import 'package:gemini_ai/widgets/AppBar.dart';
import 'package:gemini_ai/widgets/ImagePreview.dart';
import 'package:gemini_ai/widgets/InputArea.dart';
import 'package:gemini_ai/widgets/MessageList.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatScreen extends StatefulWidget {
  final int? chatId;
  final String? chatName;
  const ChatScreen({super.key, this.chatId, this.chatName});
  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<AttachedFile> _attachedFiles = [];
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  int? _currentChatId;
  ChatSession? _chatSession;
  bool _isStreaming = false;
  String _streamingResponse = '';
  final List<Content> _chatHistory = [];

  // ✅ gemini-3.1-flash-lite-preview — free tier, all input types supported
  static const _targetModel = 'gemini-3.1-flash-lite-preview';

  late final GenerativeModel _model;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: _targetModel,
      apiKey: apiKey!,
      generationConfig: GenerationConfig(
        maxOutputTokens: 8192,
        temperature: 1.0, // ✅ Keep at 1.0 per Gemini 3 docs
      ),
    );
    _currentChatId = widget.chatId;
    if (_currentChatId != null) {
      _loadMessages(_currentChatId!);
    } else {
      _startFreshSession();
    }
  }

  // ─── Session ───────────────────────────────────────────────────

  void _startFreshSession() {
    _chatSession = _model.startChat(history: List.from(_chatHistory));
  }

  Future<void> _loadMessages(int chatId) async {
    final messages = await ChatDatabaseHelper.instance.getMessages(chatId);
    if (mounted) setState(() { _messages.clear(); _chatHistory.clear(); });
    for (final msg in messages) {
      final text = msg['text'] as String;
      final type = msg['type'] as String;
      // Only text + response go into Gemini history (files not stored as binary)
      if (type == 'text') _chatHistory.add(Content.text(text));
      if (type == 'response') _chatHistory.add(Content.model([TextPart(text)]));
      if (mounted) setState(() => _messages.add({'text': text, 'type': type}));
    }
    _startFreshSession();
  }

  // ─── File picking ──────────────────────────────────────────────

  /// Request storage/media permission for the given file type
  /// Handles both Android 13+ (granular) and older (READ_EXTERNAL_STORAGE)
  Future<bool> _requestStoragePermission(String type) async {
    if (!Platform.isAndroid) return true;

    final sdkInt = await _getAndroidSdkVersion();

    Permission permission;
    if (sdkInt >= 33) {
      // Android 13+ — granular media permissions
      if (type == 'video') permission = Permission.videos;
      else if (type == 'audio') permission = Permission.audio;
      else permission = Permission.manageExternalStorage; // pdf fallback
    } else {
      // Android 12 and below — legacy storage permission
      permission = Permission.storage;
    }

    var status = await permission.status;
    if (status.isGranted) return true;

    status = await permission.request();
    if (status.isGranted) return true;

    if (mounted) {
      if (status.isPermanentlyDenied) {
        _showSnackBar('Permission denied permanently. Enable in app Settings.', Colors.red.shade700);
        await openAppSettings();
      } else {
        _showSnackBar('Storage permission denied.', Colors.red.shade700);
      }
    }
    return false;
  }

  Future<int> _getAndroidSdkVersion() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt;
    } catch (_) {
      return 30; // safe fallback
    }
  }

  /// Called from InputArea via onPickFile(type)
  Future<void> _pickFile(String type) async {
    try {
      if (type == 'image') {
        final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
        if (picked != null && mounted) {
          setState(() => _attachedFiles.add(AttachedFile(file: picked, type: 'image')));
        }
        return;
      }

      // Request permission before opening file picker
      final granted = await _requestStoragePermission(type);
      if (!granted) return;

      FileType fileType;
      List<String>? extensions;
      switch (type) {
        case 'video': fileType = FileType.video; break;
        case 'audio': fileType = FileType.audio; break;
        case 'pdf':   fileType = FileType.custom; extensions = ['pdf']; break;
        default: return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: extensions,
        allowCompression: false,
        withData: true,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) return;
      final pf = result.files.single;

      String filePath;
      if (pf.path != null) {
        filePath = pf.path!;
      } else if (pf.bytes != null) {
        final dir = await getTemporaryDirectory();
        final ext = pf.extension ?? type;
        final name = pf.name.isNotEmpty ? pf.name : 'file_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final tmp = File('${dir.path}/$name');
        await tmp.writeAsBytes(pf.bytes!);
        filePath = tmp.path;
      } else {
        _showSnackBar('Could not read file. Try a different file.', Colors.red.shade700);
        return;
      }

      if (mounted) setState(() => _attachedFiles.add(AttachedFile(file: XFile(filePath), type: type)));
    } catch (e, stack) {
      debugPrint('_pickFile error: $e\n$stack');
      _showSnackBar('Could not pick file: ${e.toString()}', Colors.red.shade700);
    }
  }

  /// Called when InputArea finishes a voice recording
  void _onAudioRecorded(String path) {
    if (mounted) setState(() => _attachedFiles.add(AttachedFile(file: XFile(path), type: 'audio')));
  }

  /// Called when suggestion chip tapped — fill controller
  void _onSuggestionTap(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
  }

  // ─── MIME resolution ───────────────────────────────────────────

  /// Returns the correct MIME type string for the Gemini API
  String _mimeType(AttachedFile f) {
    final ext = f.path.split('.').last.toLowerCase();
    return switch (f.type) {
      'image' => switch (ext) {
        'png'  => 'image/png',
        'gif'  => 'image/gif',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        'heif' => 'image/heif',
        _      => 'image/jpeg',
      },
      'video' => switch (ext) {
        'mp4'  => 'video/mp4',
        'mpeg' => 'video/mpeg',
        'mov'  => 'video/mov',
        'avi'  => 'video/avi',
        'flv'  => 'video/x-flv',
        'webm' => 'video/webm',
        'wmv'  => 'video/wmv',
        '3gp'  => 'video/3gpp',
        _      => 'video/mp4',
      },
      'audio' => switch (ext) {
        'mp3'  => 'audio/mp3',
        'wav'  => 'audio/wav',
        'aac'  => 'audio/aac',
        'ogg'  => 'audio/ogg',
        'flac' => 'audio/flac',
        'm4a'  => 'audio/m4a',
        _      => 'audio/mp3',
      },
      'pdf'   => 'application/pdf',
      _       => 'application/octet-stream',
    };
  }

  // ─── Send message ──────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty && _attachedFiles.isEmpty) {
      _showAlert('Please enter a message or attach a file.');
      return;
    }
    if (_chatSession == null) {
      _showAlert('Chat session not ready — please wait.');
      return;
    }

    setState(() { _isLoading = true; _isStreaming = true; _streamingResponse = ''; });

    final filesCopy = List<AttachedFile>.from(_attachedFiles);
    final msgCopy = message;

    try {
      final chatId = _currentChatId ?? await _createNewChat();

      // Persist user inputs to DB
      if (msgCopy.isNotEmpty) {
        await ChatDatabaseHelper.instance.insertMessage({
          'chat_id': chatId, 'text': msgCopy, 'type': 'text',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      for (final f in filesCopy) {
        await ChatDatabaseHelper.instance.insertMessage({
          'chat_id': chatId, 'text': f.path, 'type': f.type,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Show in UI immediately
      setState(() {
        if (msgCopy.isNotEmpty) {
          _messages.add({'text': msgCopy, 'type': 'text'});
          _chatHistory.add(Content.text(msgCopy));
        }
        for (final f in filesCopy) _messages.add({'text': f.path, 'type': f.type});
        _messages.add({'text': '', 'type': 'response'}); // streaming placeholder
      });
      final responseIndex = _messages.length - 1;

      _controller.clear();
      _attachedFiles.clear();

      // ✅ Build Content.multi parts per Gemini SDK docs
      final parts = <Part>[];
      if (msgCopy.isNotEmpty) parts.add(TextPart(msgCopy));

      for (final f in filesCopy) {
        final bytes = await File(f.path).readAsBytes();
        parts.add(DataPart(_mimeType(f), bytes));
      }

      // ✅ Stream response
      final stream = _chatSession!.sendMessageStream(Content.multi(parts));

      await for (final chunk in stream) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty && mounted) {
          setState(() {
            _streamingResponse += text;
            _messages[responseIndex] = {'text': _streamingResponse, 'type': 'response'};
          });
        }
      }

      if (_streamingResponse.isEmpty && mounted) {
        setState(() {
          _messages[responseIndex] = {
            'text': '_(No response — the model returned empty output.)_',
            'type': 'response',
          };
        });
      }

      // Persist AI response
      await ChatDatabaseHelper.instance.insertMessage({
        'chat_id': chatId, 'text': _streamingResponse, 'type': 'response',
        'created_at': DateTime.now().toIso8601String(),
      });
      _chatHistory.add(Content.model([TextPart(_streamingResponse)]));

    } on GenerativeAIException catch (e) {
      _handleAiError(e);
    } catch (e, stack) {
      debugPrint('_sendMessage error: $e\n$stack');
      _showSnackBar('Error: $e', Colors.red.shade700);
    } finally {
      if (mounted) setState(() { _isLoading = false; _isStreaming = false; });
    }
  }

  // ─── Chat management ───────────────────────────────────────────

  Future<int> _createNewChat() async {
    final chats = await ChatDatabaseHelper.instance.getChats();
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final label = '${_generateRandomString(6)}-${chats.length + 1}';
    final newId = await ChatDatabaseHelper.instance.insertChat({'name': 'Chat $label', 'created_at': now});
    if (mounted) setState(() { _currentChatId = newId; _chatHistory.clear(); });
    _startFreshSession();
    return newId;
  }

  void _createNewChatByDrawer() {
    setState(() { _currentChatId = null; _messages.clear(); _chatHistory.clear(); _attachedFiles.clear(); });
    _startFreshSession();
  }

  String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  // ─── Error handling ────────────────────────────────────────────

  void _handleAiError(GenerativeAIException e) {
    debugPrint('GenerativeAIException: ${e.message}');
    final msg = e.message.toLowerCase();
    String friendly;
    if (msg.contains('api_key') || msg.contains('permission')) {
      friendly = 'Invalid API key. Check your .env file.';
    } else if (msg.contains('quota') || msg.contains('rate')) {
      friendly = 'Rate limit hit. Wait a moment, or switch model in .env';
    } else if (msg.contains('model') || msg.contains('not found') || msg.contains('404')) {
      friendly = 'Model "$_targetModel" not accessible with your API key.';
    } else if (msg.contains('size') || msg.contains('too large') || msg.contains('limit')) {
      friendly = 'File too large for the API. Try a smaller file.';
    } else {
      friendly = 'Gemini error: ${e.message}';
    }
    _showSnackBar(friendly, Colors.red.shade700);
  }

  // ─── Helpers ───────────────────────────────────────────────────

  void _showAlert(String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Notice', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text(message, style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.6), fontSize: 13)),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: GoogleFonts.dmSans(color: const Color(0xFF6C63FF))))],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 5),
    ));
  }

  // ─── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      resizeToAvoidBottomInset: true,
      appBar: ChatAppBar(onExit: () => exit(1), chatName: widget.chatName),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: MessageList(messages: _messages, isStreaming: _isStreaming, onSuggestionTap: _onSuggestionTap),
              ),
            ),
            if (_attachedFiles.isNotEmpty)
              ImagePreviewList(files: _attachedFiles, onRemove: (i) => setState(() => _attachedFiles.removeAt(i))),
            InputArea(
              controller: _controller,
              isLoading: _isLoading,
              onPickFile: _pickFile,
              onSendMessage: _sendMessage,
              onAudioRecorded: _onAudioRecorded,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Drawer ────────────────────────────────────────────────────

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0D0D18),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            decoration: BoxDecoration(color: const Color(0xFF0D0D18), border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06)))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 16)],
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 16),
              Text('Gemini AI', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(_targetModel, style: GoogleFonts.dmSans(color: const Color(0xFF6C63FF), fontSize: 11, fontWeight: FontWeight.w500)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: () { Navigator.pop(context); _createNewChatByDrawer(); },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('New Chat', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: ChatDatabaseHelper.instance.getChats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF), strokeWidth: 2));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No chats yet', style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.25), fontSize: 14)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final chat = snapshot.data![index];
                    final isActive = _currentChatId == chat['id'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF6C63FF).withOpacity(0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isActive ? const Color(0xFF6C63FF).withOpacity(0.3) : Colors.transparent),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        leading: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(color: isActive ? const Color(0xFF6C63FF).withOpacity(0.2) : Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.chat_bubble_outline_rounded, size: 15, color: isActive ? const Color(0xFF6C63FF) : Colors.white.withOpacity(0.35)),
                        ),
                        title: Text(chat['name'], style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: isActive ? Colors.white : Colors.white.withOpacity(0.6)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(chat['created_at'] ?? '', style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white.withOpacity(0.2))),
                        trailing: GestureDetector(onTap: () => _confirmDeleteChat(chat), child: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white.withOpacity(0.2))),
                        onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat['id'], chatName: chat['name']))),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteChat(Map<String, dynamic> chat) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Chat', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text('This will permanently delete this chat and all its messages.', style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.6), fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.4)))),
          TextButton(
            onPressed: () async {
              await ChatDatabaseHelper.instance.deleteChat(chat['id']);
              if (mounted) Navigator.pop(context);
              setState(() {
                if (_currentChatId == chat['id']) {
                  _currentChatId = null; _messages.clear(); _chatHistory.clear(); _attachedFiles.clear();
                  _startFreshSession();
                }
              });
            },
            child: Text('Delete', style: GoogleFonts.dmSans(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}