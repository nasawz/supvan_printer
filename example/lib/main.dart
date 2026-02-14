import 'package:flutter/material.dart';
import 'package:supvan_printer/supvan_printer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supvan Printer Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const PrinterHomePage(),
    );
  }
}

class PrinterHomePage extends StatefulWidget {
  const PrinterHomePage({super.key});

  @override
  State<PrinterHomePage> createState() => _PrinterHomePageState();
}

class _PrinterHomePageState extends State<PrinterHomePage> {
  final _printer = SupvanPrinter.instance;
  final List<PrinterDevice> _devices = [];
  PrinterDevice? _connectedDevice;
  PrinterConnectionState _connectionState = PrinterConnectionState.disconnected;
  bool _isScanning = false;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _printer.scanResults.listen((device) {
      if (!_devices.any((d) => d.id == device.id)) {
        setState(() => _devices.add(device));
      }
    });
    _printer.connectionState.listen((state) {
      setState(() => _connectionState = state);
    });
  }

  Future<void> _startScan() async {
    setState(() {
      _devices.clear();
      _isScanning = true;
    });
    try {
      await _printer.startScan();
      // Auto-stop after 5 seconds
      Future.delayed(const Duration(seconds: 5), () async {
        await _printer.stopScan();
        if (mounted) setState(() => _isScanning = false);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    }
  }

  Future<void> _connect(PrinterDevice device) async {
    final success = await _printer.connect(device.id, bypassWhitelist: true);
    if (success && mounted) {
      setState(() => _connectedDevice = device);
    }
  }

  Future<void> _disconnect() async {
    await _printer.disconnect();
    if (mounted) {
      setState(() => _connectedDevice = null);
    }
  }

  Future<void> _queryStatus() async {
    try {
      final status = await _printer.getStatus();
      setState(() => _statusText = status.toString());
    } catch (e) {
      setState(() => _statusText = 'Error: $e');
    }
  }

  Future<void> _printTest() async {
    try {
      final result = await _printer.print(PrintJob(
        labelWidth: 40,
        labelHeight: 30,
        copies: 1,
        density: 4,
        gap: 6,
        pages: [
          PrintPage(
            width: 40,
            height: 30,
            items: [
              const PrintItem.text(
                x: 6,
                y: 5,
                width: 10,
                height: 2,
                content: 'SUPVAN',
                fontSize: 3,
              ),
              const PrintItem.barcode(
                x: 1,
                y: 10,
                width: 23,
                height: 3,
                content: '123456',
              ),
              const PrintItem.qrCode(
                x: 4,
                y: 15,
                width: 6,
                height: 6,
                content: '654321',
              ),
            ],
          ),
        ],
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result ? 'Print success' : 'Print failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connectionState == PrinterConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supvan Printer Demo'),
        actions: [
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled),
              onPressed: _disconnect,
              tooltip: 'Disconnect',
            ),
        ],
      ),
      body: Column(
        children: [
          // Connection status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: isConnected ? Colors.green.shade50 : Colors.grey.shade100,
            child: Row(
              children: [
                Icon(
                  isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                  color: isConnected ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isConnected
                        ? 'Connected: ${_connectedDevice?.name ?? "Unknown"}'
                        : 'Not connected',
                    style: TextStyle(
                      color: isConnected ? Colors.green.shade800 : Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_connectionState == PrinterConnectionState.connecting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // Status text
          if (_statusText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Status: $_statusText',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),

          // Action buttons
          if (isConnected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _queryStatus,
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Status'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _printTest,
                      icon: const Icon(Icons.print),
                      label: const Text('Print Test'),
                    ),
                  ),
                ],
              ),
            ),

          // Device list
          Expanded(
            child: _devices.isEmpty && !_isScanning
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bluetooth_searching,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('Tap scan to find printers',
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      final isCurrent = device.id == _connectedDevice?.id;
                      return ListTile(
                        leading: Icon(
                          isCurrent
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth,
                          color: isCurrent ? Colors.green : null,
                        ),
                        title: Text(device.name),
                        subtitle: Text(device.id),
                        trailing: device.rssi != null
                            ? Text('${device.rssi} dBm',
                                style: Theme.of(context).textTheme.bodySmall)
                            : null,
                        onTap: isConnected ? null : () => _connect(device),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: isConnected
          ? null
          : FloatingActionButton.extended(
              onPressed: _isScanning ? null : _startScan,
              icon: _isScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search),
              label: Text(_isScanning ? 'Scanning...' : 'Scan'),
            ),
    );
  }
}
