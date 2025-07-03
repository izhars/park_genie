import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Package {
  final String id;
  final String title;
  final double price;
  final String duration;
  final int durationInDays;
  final int? maxEntriesPerDay;
  final List<String> features;
  final String color;
  final String icon;
  final String description;
  final bool isActive;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;

  Package({
    required this.id,
    required this.title,
    required this.price,
    required this.duration,
    required this.durationInDays,
    this.maxEntriesPerDay,
    required this.features,
    required this.color,
    required this.icon,
    required this.description,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Package.fromJson(Map<String, dynamic> json) {
    return Package(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      duration: json['duration'] ?? '',
      durationInDays: json['durationInDays'] ?? 0,
      maxEntriesPerDay: json['maxEntriesPerDay'],
      features: List<String>.from(json['features'] ?? []),
      color: json['color'] ?? '#000000',
      icon: json['icon'] ?? 'star_border',
      description: json['description'] ?? '',
      isActive: json['isActive'] ?? false,
      sortOrder: json['sortOrder'] ?? 0,
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }

  Color getColor() {
    String hex = color.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  IconData getIcon() {
    switch (icon) {
      case 'star_outline': return Icons.star_outline;
      case 'workspace_premium': return Icons.workspace_premium;
      case 'diamond_outlined': return Icons.diamond_outlined;
      default: return Icons.star_border;
    }
  }
}