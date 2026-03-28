import 'package:flutter/material.dart';
import 'services/mqtt_service.dart';

void main() {
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
  bool isMotorOn = false;

  @override
  void initState() {
    super.initState();
    mqtt.onConnectedCallback = () {
      print("UI updating after MQTT connect"); // 🔥 debug
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

  void startMotor() {
    print("START BUTTON CLICKED"); // 🔥 ADD THIS
    setState(() => isMotorOn = true);
    mqtt.publish("ON");
  }

  void stopMotor() {
    print("STOP BUTTON CLICKED"); // 🔥 ADD THIS
    setState(() => isMotorOn = false);
    mqtt.publish("OFF");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Motor Control System"),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔵 Status Indicator
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isMotorOn ? Colors.green : Colors.red,
              ),
              child: Icon(
                isMotorOn ? Icons.power : Icons.power_off,
                size: 70,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              !isConnected
                  ? "Connecting..."
                  : (isMotorOn ? "Motor Running" : "Motor Stopped"),
              style: TextStyle(
                color: !isConnected
                    ? Colors.orange
                    : (isMotorOn ? Colors.green : Colors.red),
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: (isConnected && !isMotorOn) ? startMotor : null,
              child: const Text("START"),
            ),

            ElevatedButton(
              onPressed: (isConnected && isMotorOn) ? stopMotor : null,
              child: const Text("STOP"),
            ),
          ],
        ),
      ),
    );
  }
}
