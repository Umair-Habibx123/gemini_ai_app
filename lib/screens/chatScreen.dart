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
  bool _isFirstAttempt = true;

  late GenerativeModel _model;

  // Add this to your state variables
  int _currentModelIndex = 0; // tracks which fallback we're on

  String get _activeModel => geminiModels[_currentModelIndex];

  // Replace initState model setup
  @override
  void initState() {
    super.initState();
    _currentModelIndex = 0;
    _buildModel(_activeModel);
    _currentChatId = widget.chatId;
    if (_currentChatId != null) {
      _loadMessages(_currentChatId!);
    } else {
      _startFreshSession();
    }
  }

  void _buildModel(String modelName) {
    _model = GenerativeModel(
      model: modelName,
      apiKey: apiKey!,
      generationConfig: GenerationConfig(
        maxOutputTokens: 8192,
        temperature: 1.0,
      ),
    );
    debugPrint('🤖 Active model: $modelName'); // ✅ console log
    if (mounted) setState(() => geminiModel = modelName);
  }

  // ─── Session ───────────────────────────────────────────────────

  void _startFreshSession() {
    _chatSession = _model.startChat(history: List.from(_chatHistory));
  }

  Future<void> _loadMessages(int chatId) async {
    final messages = await ChatDatabaseHelper.instance.getMessages(chatId);
    if (mounted)
      setState(() {
        _messages.clear();
        _chatHistory.clear();
      });
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
      if (type == 'video')
        permission = Permission.videos;
      else if (type == 'audio')
        permission = Permission.audio;
      else
        permission = Permission.manageExternalStorage; // pdf fallback
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
        _showSnackBar(
          'Permission denied permanently. Enable in app Settings.',
          Colors.red.shade700,
        );
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
        final picked = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
        if (picked != null && mounted) {
          setState(
            () => _attachedFiles.add(AttachedFile(file: picked, type: 'image')),
          );
        }
        return;
      }

      // Request permission before opening file picker
      final granted = await _requestStoragePermission(type);
      if (!granted) return;

      FileType fileType;
      List<String>? extensions;
      switch (type) {
        case 'video':
          fileType = FileType.video;
          break;
        case 'audio':
          fileType = FileType.audio;
          break;
        case 'pdf':
          fileType = FileType.custom;
          extensions = ['pdf'];
          break;
        default:
          return;
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
        final name =
            pf.name.isNotEmpty
                ? pf.name
                : 'file_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final tmp = File('${dir.path}/$name');
        await tmp.writeAsBytes(pf.bytes!);
        filePath = tmp.path;
      } else {
        _showSnackBar(
          'Could not read file. Try a different file.',
          Colors.red.shade700,
        );
        return;
      }

      if (mounted)
        setState(
          () => _attachedFiles.add(
            AttachedFile(file: XFile(filePath), type: type),
          ),
        );
    } catch (e, stack) {
      debugPrint('_pickFile error: $e\n$stack');
      _showSnackBar(
        'Could not pick file: ${e.toString()}',
        Colors.red.shade700,
      );
    }
  }

  /// Called when InputArea finishes a voice recording
  void _onAudioRecorded(String path) {
    if (mounted)
      setState(
        () =>
            _attachedFiles.add(AttachedFile(file: XFile(path), type: 'audio')),
      );
  }

  /// Called when suggestion chip tapped — fill controller
  void _onSuggestionTap(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
  }

  // ─── MIME resolution ───────────────────────────────────────────

  /// Returns the correct MIME type string for the Gemini API
  String _mimeType(AttachedFile f) {
    final ext = f.path.split('.').last.toLowerCase();
    return switch (f.type) {
      'image' => switch (ext) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        'heif' => 'image/heif',
        _ => 'image/jpeg',
      },
      'video' => switch (ext) {
        'mp4' => 'video/mp4',
        'mpeg' => 'video/mpeg',
        'mov' => 'video/mov',
        'avi' => 'video/avi',
        'flv' => 'video/x-flv',
        'webm' => 'video/webm',
        'wmv' => 'video/wmv',
        '3gp' => 'video/3gpp',
        _ => 'video/mp4',
      },
      'audio' => switch (ext) {
        'mp3' => 'audio/mp3',
        'wav' => 'audio/wav',
        'aac' => 'audio/aac',
        'ogg' => 'audio/ogg',
        'flac' => 'audio/flac',
        'm4a' => 'audio/m4a',
        _ => 'audio/mp3',
      },
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }

  // ─── Send message ──────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty && _attachedFiles.isEmpty) {
      _showAlert('Please enter a message or attach a file.');
      return;
    }

    // ✅ Always reset to top model at the start of each new message
    _currentModelIndex = 0;
    _buildModel(_activeModel);
     _isFirstAttempt = true;    

     setState(() {
    _isLoading = true;
    _isStreaming = true;
    _streamingResponse = '';
  });

    final filesCopy = List<AttachedFile>.from(_attachedFiles);
    final msgCopy = message;

    final parts = <Part>[];
    if (msgCopy.isNotEmpty) parts.add(TextPart(msgCopy));
    for (final f in filesCopy) {
      final bytes = await File(f.path).readAsBytes();
      parts.add(DataPart(_mimeType(f), bytes));
    }

    await _sendWithFallback(msgCopy, filesCopy, parts);
  }

  Future<void> _sendWithFallback(
  String msgCopy,
  List<AttachedFile> filesCopy,
  List<Part> parts,
) async {
  try {
    final chatId = _currentChatId ?? await _createNewChat();

    // ✅ Only persist + add UI messages on the very first attempt
    if (_isFirstAttempt) {
      _isFirstAttempt = false; // ✅ flip immediately so retries skip this

      if (msgCopy.isNotEmpty) {
        await ChatDatabaseHelper.instance.insertMessage({
          'chat_id': chatId,
          'text': msgCopy,
          'type': 'text',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      for (final f in filesCopy) {
        await ChatDatabaseHelper.instance.insertMessage({
          'chat_id': chatId,
          'text': f.path,
          'type': f.type,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      setState(() {
        if (msgCopy.isNotEmpty) {
          _messages.add({'text': msgCopy, 'type': 'text'});
          _chatHistory.add(Content.text(msgCopy));
        }
        for (final f in filesCopy)
          _messages.add({'text': f.path, 'type': f.type});
        _messages.add({'text': '', 'type': 'response'}); // placeholder
      });

      _controller.clear();
      _attachedFiles.clear();
    }

    final responseIndex = _messages.lastIndexWhere(
      (m) => m['type'] == 'response',
    );

    // Rebuild session with current model
    _startFreshSession();
    debugPrint('📡 Sending with model: ${geminiModels[_currentModelIndex]}');

    final stream = _chatSession!.sendMessageStream(Content.multi(parts));

    await for (final chunk in stream) {
      final text = chunk.text;
      if (text != null && text.isNotEmpty && mounted) {
        setState(() {
          _streamingResponse += text;
          _messages[responseIndex] = {
            'text': _streamingResponse,
            'type': 'response',
          };
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

    await ChatDatabaseHelper.instance.insertMessage({
      'chat_id': chatId,
      'text': _streamingResponse,
      'type': 'response',
      'created_at': DateTime.now().toIso8601String(),
    });
    _chatHistory.add(Content.model([TextPart(_streamingResponse)]));

  } on GenerativeAIException catch (e) {
    if (_shouldFallback(e) && _currentModelIndex < geminiModels.length - 1) {
      _currentModelIndex++;
      final nextModel = geminiModels[_currentModelIndex];
      debugPrint('⚠️ Model ${geminiModels[_currentModelIndex - 1]} failed → trying $nextModel (${_currentModelIndex}/${geminiModels.length - 1})');
      _buildModel(nextModel);
      await _sendWithFallback(msgCopy, filesCopy, parts);
    } else {
      debugPrint('❌ All ${geminiModels.length} models exhausted. Last error: ${e.message}');
      _handleAiError(e);
    }
  } catch (e, stack) {
    debugPrint('_sendMessage error: $e\n$stack');
    _showSnackBar('Error: $e', Colors.red.shade700);
  } finally {
    if (mounted)
      setState(() {
        _isLoading = false;
        _isStreaming = false;
      });
  }
}

  /// Returns true if the error is worth retrying on a different model
  bool _shouldFallback(GenerativeAIException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('high demand') ||
        msg.contains('temporarily') ||
        msg.contains('overloaded') ||
        msg.contains('503') ||
        msg.contains('quota') ||
        msg.contains('rate') ||
        msg.contains('not found') ||
        msg.contains('404');
  }

  // ─── Chat management ───────────────────────────────────────────

  Future<int> _createNewChat() async {
    final chats = await ChatDatabaseHelper.instance.getChats();
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final label = '${_generateRandomString(6)}-${chats.length + 1}';
    final newId = await ChatDatabaseHelper.instance.insertChat({
      'name': 'Chat $label',
      'created_at': now,
    });
    if (mounted)
      setState(() {
        _currentChatId = newId;
        _chatHistory.clear();
      });
    _startFreshSession();
    return newId;
  }

  void _createNewChatByDrawer() {
    setState(() {
      _currentChatId = null;
      _messages.clear();
      _chatHistory.clear();
      _attachedFiles.clear();
    });
    _startFreshSession();
  }

  String _generateRandomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
      ),
    );
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
    } else if (msg.contains('high demand') || msg.contains('temporarily')) {
      // ✅ catch this first
      friendly =
          'Gemini is experiencing high demand. Please try again in a moment.';
    } else if (msg.contains('not found') || msg.contains('404')) {
      // ✅ removed 'model'
      friendly =
          'Model "${geminiModel ?? 'unknown'}" not accessible with your API key.';
    } else if (msg.contains('size') ||
        msg.contains('too large') ||
        msg.contains('limit')) {
      friendly = 'File too large for the API. Try a smaller file.';
    } else {
      friendly = 'Gemini error: ${e.message}'; // ✅ fallback shows real message
    }
    _showSnackBar(friendly, Colors.red.shade700);
  }

  // ─── Helpers ───────────────────────────────────────────────────

  void _showAlert(String message) {
    showDialog<void>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Notice',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              message,
              style: GoogleFonts.dmSans(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'OK',
                  style: GoogleFonts.dmSans(color: const Color(0xFF6C63FF)),
                ),
              ),
            ],
          ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      resizeToAvoidBottomInset: true,
      appBar: ChatAppBar(
        onExit: () => exit(1),
        chatName: widget.chatName,
        modelName: geminiModel, // ✅ pass it down
      ),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: MessageList(
                  messages: _messages,
                  isStreaming: _isStreaming,
                  onSuggestionTap: _onSuggestionTap,
                ),
              ),
            ),
            if (_attachedFiles.isNotEmpty)
              ImagePreviewList(
                files: _attachedFiles,
                onRemove: (i) => setState(() => _attachedFiles.removeAt(i)),
              ),
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
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D18),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.3),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Gemini AI',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  geminiModel ?? 'unknown',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF6C63FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _createNewChatByDrawer();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'New Chat',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: ChatDatabaseHelper.instance.getChats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6C63FF),
                      strokeWidth: 2,
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No chats yet',
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withOpacity(0.25),
                        fontSize: 14,
                      ),
                    ),
                  );
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
                        color:
                            isActive
                                ? const Color(0xFF6C63FF).withOpacity(0.12)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isActive
                                  ? const Color(0xFF6C63FF).withOpacity(0.3)
                                  : Colors.transparent,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color:
                                isActive
                                    ? const Color(0xFF6C63FF).withOpacity(0.2)
                                    : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 15,
                            color:
                                isActive
                                    ? const Color(0xFF6C63FF)
                                    : Colors.white.withOpacity(0.35),
                          ),
                        ),
                        title: Text(
                          chat['name'],
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color:
                                isActive
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          chat['created_at'] ?? '',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        trailing: GestureDetector(
                          onTap: () => _confirmDeleteChat(chat),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        onTap:
                            () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => ChatScreen(
                                      chatId: chat['id'],
                                      chatName: chat['name'],
                                    ),
                              ),
                            ),
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
      builder:
          (_) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Delete Chat',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              'This will permanently delete this chat and all its messages.',
              style: GoogleFonts.dmSans(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await ChatDatabaseHelper.instance.deleteChat(chat['id']);
                  if (mounted) Navigator.pop(context);
                  setState(() {
                    if (_currentChatId == chat['id']) {
                      _currentChatId = null;
                      _messages.clear();
                      _chatHistory.clear();
                      _attachedFiles.clear();
                      _startFreshSession();
                    }
                  });
                },
                child: Text(
                  'Delete',
                  style: GoogleFonts.dmSans(color: Colors.redAccent),
                ),
              ),
            ],
          ),
    );
  }
}
