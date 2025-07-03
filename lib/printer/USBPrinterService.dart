import 'dart:convert';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart' as usb;
import 'PrinterDatabaseHelper.dart';
import 'PrinterType.dart';

class USBPrinterService {
  static final USBPrinterService _instance = USBPrinterService._internal();
  factory USBPrinterService() => _instance;

  final PrinterDatabaseHelper _dbHelper = PrinterDatabaseHelper();

  usb.UsbPort? _port;
  usb.UsbDevice? _connectedDevice;

  USBPrinterService._internal();

  /// Scan for connected USB devices
  Future<List<usb.UsbDevice>> scanUSBDevices() async {
    return await usb.UsbSerial.listDevices();
  }

  /// Connect to a USB device
  Future<bool> connectToDevice(usb.UsbDevice device) async {
    _port = await device.create();
    if (_port == null) return false;

    bool open = await _port!.open();
    if (!open) return false;

    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(
      9600, usb.UsbPort.DATABITS_8, usb.UsbPort.STOPBITS_1, usb.UsbPort.PARITY_NONE,
    );

    _connectedDevice = device;

    // Save to database
    await savePrinterToDatabase(device);

    return true;
  }

  /// Save USB printer info to database
  Future<void> savePrinterToDatabase(usb.UsbDevice device) async {
    final printerType = PrinterType(
      name: "USB Printer (${device.productName ?? "Unnamed"})",
      address: device.deviceId.toString(),
      deviceType: "usb",
      isDefault: true,
      isActive: true,
      lastConnected: DateTime.now(),
      connectionParams: {
        "vendorId": device.vid,
        "productId": device.pid,
        "manufacturer": device.manufacturerName,
        "productName": device.productName,
      },
    );

    await _dbHelper.insertPrinterType(printerType.toMap());
  }

  /// Print a simple test receipt
  Future<bool> printTest() async {
    if (_port == null) return false;

    final List<int> bytes = [
      0x1B, 0x40, // initialize printer
      0x1B, 0x21, 0x30, // font style
      ...utf8.encode("USB Test Print\n"),
      0x1B, 0x21, 0x00, // reset font
      ...utf8.encode("Hello from USB printer!\n\n\n"),
      0x1D, 0x56, 0x00 // cut command
    ];

    await _port!.write(Uint8List.fromList(bytes));
    return true;
  }

  /// Disconnect from the USB printer
  Future<void> disconnect() async {
    await _port?.close();
    _port = null;
    _connectedDevice = null;
  }

  /// Check if USB printer is connected
  bool isConnected() => _port != null;
}
