import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserUid;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.otherUserUid,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late String chatId;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final supabase = Supabase.instance.client;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    chatId = _generateChatId(currentUid, widget.otherUserUid);
    _signInToSupabase();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // =========================
  // CORE LOGIC METHODS
  // =========================

  String _generateChatId(String uid1, String uid2) {
    final ids = [uid1, uid2];
    ids.sort();
    return ids.join('_');
  }

  Future<void> _signInToSupabase() async {
    try {
      if (supabase.auth.currentSession == null) {
        await supabase.auth.signInAnonymously();
      }
    } catch (e) {
      debugPrint('Supabase Auth Error: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final conversationRef = FirebaseFirestore.instance.collection('conversations').doc(chatId);

    _messageController.clear();

    await conversationRef.collection('messages').add({
      'type': 'text',
      'text': text,
      'senderId': currentUid,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await conversationRef.set({
      'participants': [currentUid, widget.otherUserUid],
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (widget.otherUserUid == "echo_ai") {
      _generateEchoAIReply(text);
    }
  }

  Future<void> _generateEchoAIReply(String userMessage) async {
    final conversationRef = FirebaseFirestore.instance.collection('conversations').doc(chatId);
    final apiKey = dotenv.env['GROQ_API_KEY'];

    try {
      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {"Authorization": "Bearer $apiKey", "Content-Type": "application/json"},
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": [{"role": "user", "content": userMessage}],
          "temperature": 0.7
        }),
      );

      if (response.statusCode == 200) {
        final aiReply = jsonDecode(response.body)["choices"][0]["message"]["content"];
        await conversationRef.collection('messages').add({
          'type': 'text',
          'text': aiReply,
          'senderId': 'echo_ai',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("AI Error: $e");
    }
  }

  Future<void> _sendImage() async {
    if (_isUploading) return;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final file = File(pickedFile.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'chat_images/$chatId/$fileName';

      await supabase.storage.from('chat-media').upload(filePath, file);
      final downloadUrl = supabase.storage.from('chat-media').getPublicUrl(filePath);

      await FirebaseFirestore.instance.collection('conversations').doc(chatId).collection('messages').add({
        'type': 'image',
        'mediaUrl': downloadUrl,
        'senderId': FirebaseAuth.instance.currentUser!.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Upload Error: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // =========================
  // UI BUILDER
  // =========================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1014) : const Color(0xFFF4F7FD),
      appBar: _buildModernAppBar(context, isDark),
      body: Column(
        children: [
          Expanded(child: _buildMessageStream(isDark)),
          _buildModernInputBar(context, isDark),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar(BuildContext context, bool isDark) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF16181D) : Colors.white,
      leading: IconButton(
        icon: Icon(Icons.chevron_left_rounded, color: isDark ? Colors.white : Colors.black, size: 30),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Colors.indigo, Colors.blue]),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.transparent,
              child: Text(
                widget.otherUserName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherUserName, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                Text(widget.otherUserUid == 'echo_ai' ? 'AI Assistant' : 'Online', style: GoogleFonts.poppins(fontSize: 11, color: Colors.green.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageStream(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('conversations').doc(chatId).collection('messages').orderBy('timestamp', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator.adaptive());
        final messages = snapshot.data!.docs;
        _scrollToBottom();
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final data = messages[index].data() as Map<String, dynamic>;
            final isMe = data['senderId'] == FirebaseAuth.instance.currentUser!.uid;
            if (data['type'] == 'typing') return _buildTypingIndicator(isDark);
            if (data['type'] == 'image') return _buildImageMessage(data, isMe);
            return _buildModernMessageBubble(data, isMe, isDark);
          },
        );
      },
    );
  }

  Widget _buildModernMessageBubble(Map<String, dynamic> data, bool isMe, bool isDark) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF5A57FF) : (isDark ? const Color(0xFF1E2128) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Text(data['text'] ?? '', style: GoogleFonts.inter(color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87), fontSize: 15, height: 1.4)),
      ),
    );
  }

  Widget _buildImageMessage(Map<String, dynamic> data, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        width: 240,
        height: 240,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(data['mediaUrl'], fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(16)),
        child: const Text("AI is thinking...", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
      ),
    );
  }

  Widget _buildModernInputBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF16181D) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Row(
        children: [
          IconButton(icon: Icon(Icons.add_circle_outline_rounded, color: Colors.grey.shade500), onPressed: _sendImage),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF0F1014) : const Color(0xFFF4F7FD), borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(hintText: "Type a message...", border: InputBorder.none, hintStyle: TextStyle(color: Colors.grey.shade500)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Color(0xFF5A57FF), shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}