import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
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
  late Timer _pollingTimer;
  Map<String, dynamic>? _devicesData;
  bool _isLoading = true;
  String? _error;
  final List<_Notification> _notifications = [];

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

    // Initial data fetch
    _initialFetch();

    // Start polling for data changes every 2 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _pollForChanges();
    });
  }

  @override
  void dispose() {
    _pollingTimer.cancel();
    super.dispose();
  }

  Future<void> _initialFetch() async {
    int retries = 3;
    while (retries > 0) {
      try {
        final data = await fetchDevices();
        if (mounted) {
          setState(() {
            _devicesData = data;
            _isLoading = false;
            _error = null;
          });
          _showNotification('Devices loaded successfully', Colors.green);
        }
        return;
      } catch (e) {
        retries--;
        if (retries > 0) {
          _showNotification('Retrying... (${retries} attempts left)', Colors.orange);
          await Future.delayed(const Duration(seconds: 2));
        } else {
          if (mounted) {
            setState(() {
              _error = e.toString();
              _isLoading = false;
            });
            _showNotification('Error: $e', Colors.red);
          }
        }
      }
    }
  }

  Future<void> _pollForChanges() async {
    try {
      final response = await http.get(
        Uri.parse('$DATABASE_URL/.json'),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final newData = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Update only if data changed
        if (_devicesData == null || jsonEncode(_devicesData) != jsonEncode(newData)) {
          if (mounted) {
            // Detect which device changed and show notification
            _detectChangesAndNotify(newData);
            
            setState(() {
              _devicesData = newData;
              _error = null;
            });
          }
        }
      }
    } catch (e) {
      print('Polling error: $e');
    }
  }

  void _detectChangesAndNotify(Map<String, dynamic> newData) {
    if (_devicesData == null) return;
    
    newData.forEach((deviceId, newDeviceData) {
      final oldDeviceData = _devicesData![deviceId];
      if (oldDeviceData is Map && newDeviceData is Map) {
        final oldMCFB = oldDeviceData['MOTORCONTROL']?['MCFB'];
        final newMCFB = newDeviceData['MOTORCONTROL']?['MCFB'];
        
        if (oldMCFB != newMCFB) {
          final status = newMCFB?.toString() ?? 'Unknown';
          final statusText = status == 'ON' ? 'Started' : 'Stopped';
          _showNotification('$deviceId: Motor $statusText', status == 'ON' ? Colors.green : Colors.red);
        }
      }
    });
  }

  void _showNotification(String message, Color backgroundColor) {
    final notification = _Notification(
      id: DateTime.now().millisecondsSinceEpoch,
      message: message,
      backgroundColor: backgroundColor,
    );

    setState(() {
      _notifications.add(notification);
    });
  }

  void _removeNotification(int notificationId) {
    setState(() {
      _notifications.removeWhere((n) => n.id == notificationId);
    });
  }

  void connectMQTT() async {
    await mqtt.connect();
    setState(() {});
  }

  Future<Map<String, dynamic>> fetchDevices() async {
    try {
      final response = await http.get(
        Uri.parse('$DATABASE_URL/.json'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        throw Exception('Failed to load devices: HTTP ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('Error fetching devices: Network timeout');
      throw Exception('Network timeout - Check your internet connection');
    } catch (e) {
      print('Error fetching devices: $e');
      throw Exception('Error: $e');
    }
  }

  void startMotor(String deviceId) {
    print("START BUTTON CLICKED for $deviceId");
    _showNotification('Starting $deviceId...', Colors.orange);
    updateMotorStatus(deviceId, 'ON');
    mqtt.publish("ON");
  }

  void stopMotor(String deviceId) {
    print("STOP BUTTON CLICKED for $deviceId");
    _showNotification('Stopping $deviceId...', Colors.orange);
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
        _showNotification('$deviceId: Command sent ($status)', Colors.blue);
        // Refresh data immediately after update
        await Future.delayed(const Duration(milliseconds: 300));
        _pollForChanges();
      } else {
        print('Error updating motor: ${response.statusCode}');
        _showNotification('Error: Failed to update $deviceId', Colors.red);
      }
    } catch (e) {
      print('Error updating motor status: $e');
      _showNotification('Error: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Motor Control System"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : _devicesData == null || _devicesData!.isEmpty
                      ? const Center(child: Text('No devices found'))
                      : buildDevicesList(_devicesData!),
          // Notifications Stack
          Positioned(
            bottom: 100,
            left: 10,
            right: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _notifications.map((notification) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: notification.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _removeNotification(notification.id),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _initialFetch,
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

class _Notification {
  final int id;
  final String message;
  final Color backgroundColor;

  _Notification({
    required this.id,
    required this.message,
    required this.backgroundColor,
  });
}
