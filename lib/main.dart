import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Assistant',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const AIAssistantScreen(),
    );
  }
}

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  // ============ AI RELATED ============
  List<Map<String, String>> messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isProcessing = false;
  String _aiModelPath = '';
  Map<String, dynamic>? _aiModel;
  
  // ============ SPEECH TO TEXT ============
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _spokenText = '';
  
  // ============ TEXT TO SPEECH ============
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initializeAI();
    _initializeTTS();
    _requestPermissions();
    _addWelcomeMessage();
  }

  // ============ PERMISSIONS ============
  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.storage,
    ].request();
  }

  // ============ WELCOME MESSAGE ============
  void _addWelcomeMessage() {
    setState(() {
      messages.add({
        'role': 'assistant',
        'content': '👋 السلام علیکم! میں آپ کا آف لائن AI اسسٹنٹ ہوں۔ آپ مجھ سے ٹائپ کرکے یا بول کر بات کر سکتے ہیں۔',
      });
    });
  }

  // ============ AI INITIALIZATION ============
  Future<void> _initializeAI() async {
    try {
      // Check if AI model exists in assets
      final modelData = await rootBundle.loadString('assets/ai_model.txt');
      _aiModel = json.decode(modelData);
      
      setState(() {
        messages.add({
          'role': 'assistant',
          'content': '✅ AI ماڈل کامیابی سے لوڈ ہو گیا! اب آپ آف لائن بات چیت کر سکتے ہیں۔',
        });
      });
    } catch (e) {
      print('AI Model not found in assets: $e');
      // Use simple rule-based AI if model not found
      _aiModel = null;
    }
  }

  // ============ AI RESPONSE GENERATION ============
  String _getAIResponse(String userInput) {
    if (_aiModel != null) {
      try {
        // If we have a trained model, use it
        final responses = _aiModel!['responses'] as Map<String, dynamic>?;
        if (responses != null) {
          // Simple keyword matching
          for (var entry in responses.entries) {
            if (userInput.toLowerCase().contains(entry.key.toLowerCase())) {
              return entry.value.toString();
            }
          }
        }
      } catch (e) {
        print('Error processing AI model: $e');
      }
    }

    // ============ FALLBACK: RULE-BASED RESPONSES ============
    final input = userInput.toLowerCase();
    
    if (input.contains('hello') || input.contains('hi') || input.contains('السلام')) {
      return 'السلام علیکم! میں آپ کی کیسے مدد کر سکتا ہوں؟';
    } else if (input.contains('how are you') || input.contains('کیسے ہیں')) {
      return 'میں ٹھیک ہوں، شکریہ! آپ کیسے ہیں؟';
    } else if (input.contains('name') || input.contains('نام')) {
      return 'میرا نام AI اسسٹنٹ ہے۔ میں آپ کی مدد کے لیے حاضر ہوں!';
    } else if (input.contains('help') || input.contains('مدد')) {
      return 'میں آپ کی مختلف طریقوں سے مدد کر سکتا ہوں:\n• سوالات کے جوابات\n• معلومات فراہم کرنا\n• بات چیت کرنا\n• مشورے دینا';
    } else if (input.contains('time') || input.contains('وقت')) {
      return 'موجودہ وقت: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    } else if (input.contains('date') || input.contains('تاریخ')) {
      return 'آج کی تاریخ: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
    } else if (input.contains('thanks') || input.contains('شکریہ')) {
      return 'شکریہ! کیا آپ کو کسی اور چیز میں مدد چاہیے؟';
    } else if (input.contains('bye') || input.contains('الوداع')) {
      return 'الوداع! آپ سے مل کر خوشی ہوئی۔ دوبارہ تشریف لائیں!';
    } else {
      return 'معاف کیجیے، میں اس سوال کا جواب نہیں جانتا۔ کیا آپ کچھ اور پوچھنا چاہیں گے؟';
    }
  }

  // ============ SEND MESSAGE ============
  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      messages.add({'role': 'user', 'content': message.trim()});
      _isProcessing = true;
    });

    _textController.clear();
    _scrollToBottom();

    // Simulate AI thinking
    await Future.delayed(const Duration(milliseconds: 500));

    // Get AI response
    final response = _getAIResponse(message.trim());

    setState(() {
      messages.add({'role': 'assistant', 'content': response});
      _isProcessing = false;
    });

    _scrollToBottom();

    // ============ AUTO SPEAK RESPONSE ============
    await _speakText(response);
  }

  // ============ SPEECH TO TEXT ============
  Future<void> _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          print('Speech status: $status');
        },
        onError: (error) {
          print('Speech error: $error');
          setState(() {
            _isListening = false;
          });
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
          _spokenText = '';
        });

        await _speech.listen(
          onResult: (result) {
            setState(() {
              _spokenText = result.recognizedWords;
              if (result.finalResult) {
                _isListening = false;
                _sendMessage(_spokenText);
              }
            });
          },
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ مائیکروفون دستیاب نہیں ہے')),
        );
      }
    } else {
      setState(() {
        _isListening = false;
      });
      await _speech.stop();
      
      // Send the spoken text if there is any
      if (_spokenText.isNotEmpty) {
        _sendMessage(_spokenText);
      }
    }
  }

  // ============ TEXT TO SPEECH ============
  Future<void> _initializeTTS() async {
    await _flutterTts.setLanguage("ur-PK");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> _speakText(String text) async {
    try {
      setState(() {
        _isSpeaking = true;
      });
      
      await _flutterTts.speak(text);
      
      _flutterTts.setCompletionHandler(() {
        setState(() {
          _isSpeaking = false;
        });
      });
      
      _flutterTts.setErrorHandler((error) {
        print('TTS Error: $error');
        setState(() {
          _isSpeaking = false;
        });
      });
    } catch (e) {
      print('TTS Error: $e');
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
    });
  }

  // ============ SCROLL TO BOTTOM ============
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

  // ============ CLEAR CHAT ============
  void _clearChat() {
    setState(() {
      messages.clear();
      _addWelcomeMessage();
    });
  }

  // ============ BUILD UI ============
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 AI Assistant - Offline'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearChat,
            tooltip: 'Clear Chat',
          ),
          // TTS Toggle
          IconButton(
            icon: Icon(_isSpeaking ? Icons.volume_off : Icons.volume_up),
            onPressed: _isSpeaking ? _stopSpeaking : null,
            tooltip: _isSpeaking ? 'Stop Speaking' : 'Speaking Enabled',
          ),
        ],
      ),
      body: Column(
        children: [
          // ===== CHAT MESSAGES =====
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isUser = message['role'] == 'user';
                
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isUser ? Colors.blue : Colors.grey,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      message['content']!,
                      style: TextStyle(
                        fontSize: 16,
                        color: isUser ? Colors.blue.shade900 : Colors.black87,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // ===== VOICE INPUT STATUS =====
          if (_isListening || _spokenText.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  Icon(
                    _isListening ? Icons.mic : Icons.mic_off,
                    color: _isListening ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isListening ? '🎤 سن رہا ہوں...' : _spokenText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // ===== INPUT BAR =====
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Voice Input Button
                IconButton(
                  icon: Icon(
                    _isListening ? Icons.stop : Icons.mic,
                    color: _isListening ? Colors.red : Colors.blue,
                    size: 30,
                  ),
                  onPressed: _isProcessing ? null : _startListening,
                  tooltip: _isListening ? 'Stop Recording' : 'Start Voice Input',
                ),
                
                // Text Input
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'اپنا پیغام ٹائپ کریں...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    textDirection: TextDirection.rtl,
                    onSubmitted: (text) => _sendMessage(text),
                  ),
                ),
                
                // Send Button
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue, size: 30),
                  onPressed: _isProcessing
                      ? null
                      : () => _sendMessage(_textController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }
}