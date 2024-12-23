import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Stethoscope App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Digital Stethoscope Home'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome to Digital Stethoscope',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Monitor your health remotely',
                style: TextStyle(fontSize: 16, color: Colors.blueGrey),
              ),
              SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/stethoscope.png',
                  height: 150,
                  width: 150,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => VoltageFetcher()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: Text('Connect to ESP8266 and View Voltage Reading'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VoltageFetcher extends StatefulWidget {
  const VoltageFetcher({super.key});

  @override
  _VoltageFetcherState createState() => _VoltageFetcherState();
}

class _VoltageFetcherState extends State<VoltageFetcher> {
  List<FlSpot> spots = [];
  String voltage = "Fetching...";
  bool isLoading = true;
  int timeStamp = 0;
  Timer? _pollTimer;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _mounted = false;
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Initial fetch
    _fetchVoltage();

    // Setup periodic polling every 1 second
    _pollTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _fetchVoltage();
    });
  }

  Future<void> _fetchVoltage() async {
    if (!_mounted) return;

    try {
      final response =
          await http.get(Uri.parse('http://192.168.98.198/voltage'));

      if (!_mounted) return; // Check again after async operation

      if (response.statusCode == 200) {
        if (!_mounted) return;
        setState(() {
          voltage = response.body;
          // Parse voltage value with error handling
          try {
            double voltageValue = double.tryParse(voltage
                    .split('\n')[1]
                    .split(": ")[1]
                    .replaceAll(" V", "")) ??
                0.0;

            timeStamp++;
            if (spots.length > 20) spots.removeAt(0); // Keep last 20 points
            spots.add(FlSpot(timeStamp.toDouble(), voltageValue));
            isLoading = false;
          } catch (parseError) {
            voltage = "Error parsing voltage data";
            isLoading = false;
          }
        });
      } else {
        if (!_mounted) return;
        setState(() {
          voltage = "Error: ${response.statusCode} - ${response.reasonPhrase}";
          isLoading = false;
        });
      }
    } catch (e) {
      if (!_mounted) return;
      setState(() {
        voltage = "Error: Unable to connect to ESP8266";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Voltage Monitor'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchVoltage,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          Container(
            padding: EdgeInsets.all(16),
            color:
                isLoading ? Colors.blue.withOpacity(0.1) : Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Text(
                  voltage,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
                ),
              ],
            ),
          ),

          // Graph
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 0.5,
                    verticalInterval: 5,
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text('Time (seconds)'),
                      sideTitles:
                          SideTitles(showTitles: true, reservedSize: 30),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: Text('Voltage (V)'),
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 0.5,
                        reservedSize: 40,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  minX: spots.isEmpty ? 0 : spots.first.x,
                  maxX: spots.isEmpty ? 10 : spots.last.x,
                  minY: 0,
                  maxY: 3.5,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [Colors.blue[400]!, Colors.blue[900]!],
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue[400]!.withOpacity(0.3),
                            Colors.blue[900]!.withOpacity(0.1),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _fetchVoltage,
                  icon: Icon(Icons.refresh),
                  label: Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      spots.clear();
                      timeStamp = 0;
                    });
                  },
                  icon: Icon(Icons.clear),
                  label: Text('Clear Graph'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
