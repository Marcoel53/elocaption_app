import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const EloCaptionApp());

class EloCaptionApp extends StatelessWidget {
  const EloCaptionApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EloCaption',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
      ),
      home: const ConfigPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});
  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final TextEditingController _urlController = TextEditingController();
  bool _hasUrl = false;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('backend_url');
    if (url != null && url.isNotEmpty) {
      setState(() {
        _urlController.text = url;
        _hasUrl = true;
      });
    }
  }

  Future<void> _saveUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_url', _urlController.text.trim());
    setState(() => _hasUrl = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ URL salva! Vá para a aba principal.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ Configurar Backend')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings_ethernet, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text(
              'Cole aqui a URL do seu backend (ex: https://seu-app.onrender.com)',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'https://meu-backend.onrender.com',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveUrl,
                    icon: const Icon(Icons.save),
                    label: const Text('Salvar URL'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            if (_hasUrl)
              ElevatedButton.icon(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                ),
                icon: const Icon(Icons.home),
                label: const Text('Ir para o App Principal'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _urlController = TextEditingController();
  String _status = "Aguardando link...";
  String _resultado = "";
  bool _loading = false;
  String _backendUrl = '';

  @override
  void initState() {
    super.initState();
    _loadBackendUrl();
  }

  Future<void> _loadBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backendUrl = prefs.getString('backend_url') ?? '';
    });
  }

  Future<void> _gerarLegenda() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _status = "❌ Cole um link válido!");
      return;
    }
    if (_backendUrl.isEmpty) {
      setState(() => _status = "❌ Configure a URL do backend primeiro (⚙️)!");
      return;
    }

    setState(() {
      _loading = true;
      _status = "⏳ Baixando vídeo e transcrevendo... (até 2 min)";
      _resultado = "";
    });

    try {
      final response = await http.post(
        Uri.parse("$_backendUrl/transcrever"),
        headers: {"Content-Type": "application/json"},
        body: '{"url": "$url"}',
      ).timeout(const Duration(minutes: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _resultado = data['texto'] ?? "Nenhum texto encontrado.";
          _status = "✅ Transcrição concluída!";
          _loading = false;
        });
      } else {
        setState(() {
          _status = "❌ Erro no servidor: ${response.statusCode}";
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = "❌ Erro: $e";
        _loading = false;
      });
    }
  }

  Future<void> _salvarArquivo(String extensao, String conteudo) async {
    if (_resultado.isEmpty) return;
    await Permission.storage.request();
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/legenda.$extensao");
    await file.writeAsString(conteudo);
    final snack = SnackBar(content: Text("✅ Salvo em: ${file.path}"));
    ScaffoldMessenger.of(context).showSnackBar(snack);
    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🎬 EloCaption"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ConfigPage()),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: "Cole o link do TikTok/Reels...",
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _loading ? null : _gerarLegenda,
                  icon: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_status)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _resultado.isEmpty ? "Sua legenda aparecerá aqui..." : _resultado,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _resultado.isEmpty ? null : () => _salvarArquivo("txt", _resultado),
                    icon: const Icon(Icons.text_fields),
                    label: const Text("TXT"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[800]),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _resultado.isEmpty ? null : () {
                      String srt = "1\n00:00:00,000 --> 00:00:05,000\n$_resultado\n";
                      _salvarArquivo("srt", srt);
                    },
                    icon: const Icon(Icons.closed_caption),
                    label: const Text("SRT"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[800]),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _resultado.isEmpty ? null : () async {
                      await Share.share(_resultado);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text("Compartilhar"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}