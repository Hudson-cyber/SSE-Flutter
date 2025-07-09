import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SSE Status Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: StatusMonitorScreen(),
    );
  }
}

class StatusMonitorScreen extends StatefulWidget {
  const StatusMonitorScreen({super.key});

  @override
  StatusMonitorScreenState createState() => StatusMonitorScreenState();
}

class StatusMonitorScreenState extends State<StatusMonitorScreen> {
  // StreamController para gerenciar o fluxo de status que vem do servidor
  final StreamController<String> _statusController = StreamController<String>();
  http.Client? _httpClient;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _startListeningToStatus();
  }

  Future<void> _startListeningToStatus() async {
    _httpClient = http.Client();
    try {
      final request = http.Request(
        'GET',
        Uri.parse('http://localhost:8080/status-stream'),
      );
      // O cabeçalho 'Accept' informa ao servidor que esperamos um fluxo de eventos
      request.headers['Accept'] = 'text/event-stream';

      // Envia a requisição e obtém a resposta como um Stream
      final response = await _httpClient!.send(request);

      if (response.statusCode == 200) {
        setState(() {
          _isConnected = true;
        });
        print('Conexão SSE estabelecida com sucesso!');

        // Converte o Stream de bytes da resposta para um Stream de Strings (decodificando UTF8)
        // e transforma cada 'chunk' em linhas de eventos SSE. precisa ter no back
        await for (var chunk in response.stream.transform(utf8.decoder)) {
          final lines = chunk.split('\n');
          for (var line in lines) {
            // Um evento SSE começa com 'data: '
            if (line.startsWith('data: ')) {
              final eventData = line.substring(6); // Remove "data: "
              _statusController.add(
                  eventData); // Adiciona o evento ao nosso StreamController
              print('Cliente recebeu: $eventData'); // Log no cliente
            }
          }
        }
      } else {
        _statusController.addError('Erro ao conectar: ${response.statusCode}');
        setState(() {
          _isConnected = false;
        });
      }
    } catch (e) {
      _statusController.addError('Erro de conexão SSE: $e');
      setState(() {
        _isConnected = false;
      });
      print('Erro de conexão SSE: $e');
    } finally {
      // Garante que o cliente HTTP seja fechado se a conexão terminar
      _httpClient?.close();
      setState(() {
        _isConnected = false;
      });
      print('Conexão SSE encerrada.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SSE Status Monitor'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Estado da Conexão: ${_isConnected ? 'Conectado' : 'Desconectado'}',
              style: TextStyle(
                  fontSize: 18,
                  color: _isConnected ? Colors.green : Colors.red),
            ),
            SizedBox(height: 20),
            // StreamBuilder ouve as atualizações do _statusController
            StreamBuilder<String>(
              stream: _statusController.stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text('Aguardando conexão com o servidor...'),
                    ],
                  );
                } else if (snapshot.hasError) {
                  return Text('Erro: ${snapshot.error}',
                      style: TextStyle(color: Colors.red, fontSize: 20));
                } else if (snapshot.hasData) {
                  // Decodifica o JSON recebido
                  final data = jsonDecode(snapshot.data!);
                  return Column(
                    children: [
                      Text(
                        'Status Atual:',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${data['status']}',
                        style:
                            TextStyle(fontSize: 32, color: Colors.blueAccent),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Última atualização: ${data['timestamp']}',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  );
                } else {
                  return Text('Nenhum status recebido ainda.');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _httpClient?.close(); // Fecha o cliente HTTP quando o widget é descartado
    _statusController.close(); // Fecha o StreamController
    super.dispose();
  }
}
