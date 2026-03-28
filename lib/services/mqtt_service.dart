import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  MqttServerClient? client;
  bool isConnected = false;

  Function()? onConnectedCallback; // 🔥 ADD THIS

  Future<void> connect() async {
    client = MqttServerClient(
      'test.mosquitto.org',
      'flutter_${DateTime.now().millisecondsSinceEpoch}',
    );
    client!.port = 1883;
    client!.keepAlivePeriod = 20;

    client!.onConnected = () {
      print('MQTT Connected');
      isConnected = true;

      if (onConnectedCallback != null) {
        onConnectedCallback!(); // 🔥 NOTIFY UI
      }
    };

    client!.onDisconnected = () {
      print('MQTT Disconnected');
      isConnected = false;
    };

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .startClean();

    client!.connectionMessage = connMessage;

    try {
      await client!.connect();
    } catch (e) {
      print('MQTT Error: $e');
      client!.disconnect();
    }
  }

  void publish(String message) {
    if (!isConnected || client == null) {
      print("MQTT NOT CONNECTED");
      return;
    }

    print("Publishing: $message"); // 🔥 IMPORTANT

    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    client!.publishMessage(
      'motor/control',
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }
}
