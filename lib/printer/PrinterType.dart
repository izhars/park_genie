import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

/// Custom class to represent a USB device.
/// Replace this with your actual USB printer integration class if different.
class UsbDevice {
  final int vid;
  final int pid;
  final String? manufacturerName;
  final String? productName;
  final int deviceId;

  UsbDevice({
    required this.vid,
    required this.pid,
    required this.deviceId,
    this.manufacturerName,
    this.productName,
  });
}

class PrinterType {
  final int? id;
  final String name;
  final String? address;
  final String deviceType;
  final bool isDefault;
  final bool isActive;
  final DateTime lastConnected;
  final Map<String, dynamic> connectionParams;

  PrinterType({
    this.id,
    required this.name,
    this.address,
    required this.deviceType,
    this.isDefault = false,
    this.isActive = true,
    DateTime? lastConnected,
    Map<String, dynamic>? connectionParams,
  })  : lastConnected = lastConnected ?? DateTime.now(),
        connectionParams = connectionParams ?? {} {
    if (name.isEmpty) throw ArgumentError('Printer name cannot be empty');
    if (!['usb', 'thermal', 'network', 'wifi'].contains(deviceType)) {
      throw ArgumentError('Invalid device type');
    }
  }

  // Conversion methods
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'address': address,
    'deviceType': deviceType,
    'isDefault': isDefault ? 1 : 0,
    'isActive': isActive ? 1 : 0,
    'lastConnected': lastConnected.toIso8601String(),
    'connectionParams': jsonEncode(connectionParams),
  };

  factory PrinterType.fromMap(Map<String, dynamic> map) => PrinterType(
    id: map['id'],
    name: map['name'],
    address: map['address'],
    deviceType: map['deviceType'],
    isDefault: map['isDefault'] == 1,
    isActive: map['isActive'] == 1,
    lastConnected: DateTime.parse(map['lastConnected']),
    connectionParams: jsonDecode(map['connectionParams']),
  );

  // Factory constructors
  factory PrinterType.fromBluetoothDevice(BluetoothDevice device) => PrinterType(
    name: device.name ?? 'Unknown Device',
    address: device.address,
    deviceType: 'thermal',
    connectionParams: {
      'deviceName': device.name,
      'deviceAddress': device.address,
    },
  );

  factory PrinterType.fromUsbDevice(UsbDevice device) => PrinterType(
    name: device.productName ?? 'USB Printer',
    address: device.deviceId.toString(),
    deviceType: 'usb',
    connectionParams: {
      'vendorId': device.vid,
      'productId': device.pid,
      'manufacturer': device.manufacturerName,
      'productName': device.productName,
    },
  );

  // copyWith method
  PrinterType copyWith({
    int? id,
    String? name,
    String? address,
    String? deviceType,
    bool? isDefault,
    bool? isActive,
    DateTime? lastConnected,
    Map<String, dynamic>? connectionParams,
  }) {
    return PrinterType(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      deviceType: deviceType ?? this.deviceType,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      lastConnected: lastConnected ?? this.lastConnected,
      connectionParams: connectionParams ?? Map.from(this.connectionParams),
    );
  }

  // Bluetooth reconnection helper (returns device from bonded list)
  static BluetoothDevice? findBluetoothDevice(
      List<BluetoothDevice> bondedDevices, String? address) {
    try {
      return bondedDevices.firstWhere((d) => d.address == address);
    } catch (_) {
      return null;
    }
  }

  // Connection parameter helpers
  int? get vendorId =>
      deviceType == 'usb' ? connectionParams['vendorId'] : null;

  int? get productId =>
      deviceType == 'usb' ? connectionParams['productId'] : null;

  String? get macAddress =>
      deviceType == 'thermal' ? connectionParams['deviceAddress'] : null;

  // JSON serialization
  String toJson() => jsonEncode(toMap());
  factory PrinterType.fromJson(String json) => PrinterType.fromMap(jsonDecode(json));

  // Equality
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is PrinterType &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              name == other.name &&
              address == other.address &&
              deviceType == other.deviceType &&
              isDefault == other.isDefault &&
              isActive == other.isActive &&
              lastConnected == other.lastConnected &&
              mapEquals(connectionParams, other.connectionParams);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    address,
    deviceType,
    isDefault,
    isActive,
    lastConnected,
    jsonEncode(connectionParams),
  );

  @override
  String toString() => 'PrinterType($name, $address, $deviceType, '
      'default: $isDefault, active: $isActive)';
}
