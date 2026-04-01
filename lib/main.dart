import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/mqtt_service.dart';

const String DATABASE_URL = 'https://ac119-smart-iot-controll-ef7e3-default-rtdb.firebaseio.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MotorApp());
}

class MotorApp extends StatelessWidget {
  const MotorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Motor Control System',
      theme: ThemeData.dark(),
      home: const MotorScreen(),
    );
  }
}

class MotorScreen extends StatefulWidget {
  const MotorScreen({super.key});

  @override
  State<MotorScreen> createState() => _MotorScreenState();
}

class _MotorScreenState extends State<MotorScreen> {
  final mqtt = MQTTService();
  bool isMqttReady = false;
  bool isConnected = false;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();

    mqtt.onConnectedCallback = () {
      print("UI updating after MQTT connect");
      setState(() {
        isConnected = true;
      });
    };
    mqtt.connect();
  }

  void connectMQTT() async {
    await mqtt.connect();
    setState(() {});
  }

  Future<Map<String, dynamic>> fetchDevices() async {
    try {
      final response = await http.get(
        Uri.parse('$DATABASE_URL/.json'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        throw Exception('Failed to load devices: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching devices: $e');
      throw Exception('Error: $e');
    }
  }

  void startMotor(String deviceId) {
    print("START BUTTON CLICKED for $deviceId");
    updateMotorStatus(deviceId, 'ON');
    mqtt.publish("ON");
  }

  void stopMotor(String deviceId) {
    print("STOP BUTTON CLICKED for $deviceId");
    updateMotorStatus(deviceId, 'OFF');
    mqtt.publish("OFF");
  }

  Future<void> updateMotorStatus(String deviceId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$DATABASE_URL/$deviceId/MOTORCONTROL/MCSET.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(status),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('Motor status updated successfully to $status');
      } else {
        print('Error updating motor: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating motor status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Motor Control System"),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        key: ValueKey<int>(_refreshKey),
        future: fetchDevices(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No devices found'));
          } else {
            return buildDevicesList(snapshot.data!);
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() {
          _refreshKey++;
        }),
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget buildDevicesList(Map<String, dynamic> devicesData) {
    final deviceIds = devicesData.keys.toList();

    return ListView.builder(
      itemCount: deviceIds.length,
      itemBuilder: (context, index) {
        final deviceId = deviceIds[index];
        final deviceData = devicesData[deviceId];

        if (deviceData is! Map) {
          return const SizedBox.shrink();
        }

        return DeviceCard(
          deviceId: deviceId,
          deviceData: deviceData as Map<dynamic, dynamic>,
          onStart: () => startMotor(deviceId),
          onStop: () => stopMotor(deviceId),
          isConnected: isConnected,
        );
      },
    );
  }
}

class DeviceCard extends StatelessWidget {
  final String deviceId;
  final Map<dynamic, dynamic> deviceData;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final bool isConnected;

  const DeviceCard({
    super.key,
    required this.deviceId,
    required this.deviceData,
    required this.onStart,
    required this.onStop,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final motorControl = deviceData['MOTORCONTROL'];
    final current = deviceData['CURRENT']?['AMPSGET']?.toString() ?? 'N/A';
    final voltage = deviceData['VOLTAGE']?['VOLTGET']?.toString() ?? 'N/A';
    final motorStatus = motorControl?['MOTORSTATUS']?.toString() ?? 'Unknown';
    final isMotorOn = motorControl?['MCFB']?.toString() == 'ON';

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device: $deviceId',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Status indicator
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isMotorOn ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isMotorOn ? 'Running' : 'Stopped',
                  style: TextStyle(
                    color: isMotorOn ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Data display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text('Current', style: TextStyle(fontSize: 12)),
                    Text(current, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    const Text('Voltage', style: TextStyle(fontSize: 12)),
                    Text(voltage, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    const Text('Status', style: TextStyle(fontSize: 12)),
                    Text(
                      motorStatus,
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: (isConnected && !isMotorOn) ? onStart : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('START'),
                ),
                ElevatedButton(
                  onPressed: (isConnected && isMotorOn) ? onStop : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('STOP'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
