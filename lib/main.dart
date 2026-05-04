import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const RadarApp());
}

class RadarApp extends StatelessWidget {
  const RadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: RadarHome());
  }
}

class RadarHome extends StatefulWidget {
  const RadarHome({super.key});

  @override
  State<RadarHome> createState() => _RadarHomeState();
}

class _RadarHomeState extends State<RadarHome>
    with SingleTickerProviderStateMixin {
  late WebSocketChannel channel;

  String status = "Connecting...";
  bool connected = false;

  double angle = 0;
  double distance = 0;

  List<Offset> points = [];
  List<String> logs = [];

  late AnimationController _controller;
  double sweepAngle = 0;

  @override
  void initState() {
    super.initState();

    // UI must load FIRST before socket starts
    Future.delayed(const Duration(milliseconds: 300), initWebSocket);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _controller.addListener(() {
      setState(() {
        sweepAngle = _controller.value * 2 * pi;
      });
    });
  }

  // ===================== SAFE WEBSOCKET =====================
  void initWebSocket() {
    try {
      channel = WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:8765'));

      setState(() {
        status = "Connected";
        connected = true;
      });

      channel.stream.listen(
        (data) {
          final msg = data.toString();
          _log(msg);
          _parse(msg);
        },
        onError: (e) {
          setState(() {
            status = "WebSocket Error";
            connected = false;
          });
        },
        onDone: () {
          setState(() {
            status = "Disconnected";
            connected = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        status = "Connection Failed";
      });
    }
  }

  // ===================== PARSER =====================
  void _parse(String data) {
    final parts = data.split(",");
    if (parts.length != 3) return;

    final sensor = parts[0];
    final a = double.tryParse(parts[1]);
    final d = double.tryParse(parts[2]);

    if (a == null || d == null) return;

    setState(() {
      angle = a;
      distance = d;

      double rad = angle * pi / 180;
      Offset point = Offset(cos(rad) * distance, sin(rad) * distance);

      if (sensor == "1") {
        points.add(point);
      } else if (sensor == "2") {
        points.add(Offset(-point.dx, point.dy));
      }

      if (points.length > 150) {
        points.removeAt(0);
      }
    });
  }

  void _log(String msg) {
    logs.add(msg);
    if (logs.length > 50) logs.removeAt(0);
    setState(() {});
  }

  @override
  void dispose() {
    channel.sink.close();
    _controller.dispose();
    super.dispose();
  }

  // ===================== UI =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Row(
          children: [
            // LEFT PANEL
            Expanded(
              flex: 2,
              child: Container(
                color: Colors.grey.shade900,
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected ? "🟢 CONNECTED" : "🔴 OFFLINE",
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(status, style: const TextStyle(color: Colors.white70)),
                    const Divider(),
                    Text(
                      "Angle: $angle",
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      "Distance: $distance",
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Divider(),
                    const Text(
                      "LIVE LOG",
                      style: TextStyle(color: Colors.greenAccent),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (c, i) => Text(
                          logs[i],
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // RADAR
            Expanded(
              flex: 3,
              child: Center(
                child: CustomPaint(
                  size: const Size(350, 350),
                  painter: RadarPainter(points, sweepAngle),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== RADAR PAINTER =====================
class RadarPainter extends CustomPainter {
  final List<Offset> points;
  final double sweep;

  RadarPainter(this.points, this.sweep);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 1.25;

    final bg = Paint()
      ..color = Colors.green.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, bg);

    final grid = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4, grid);
    }

    canvas.drawLine(
      center,
      Offset(center.dx + radius * cos(sweep), center.dy + radius * sin(sweep)),
      Paint()
        ..color = Colors.greenAccent
        ..strokeWidth = 2,
    );

    for (var p in points) {
      final pos = Offset(
        center.dx + (p.dx / 30) * radius,
        center.dy + (p.dy / 30) * radius,
      );

      canvas.drawCircle(pos, 6, Paint()..color = Colors.redAccent);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
