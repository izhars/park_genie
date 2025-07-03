class PackageData {
  final String userId;
  final String name;
  final String email;
  final String title;
  final double price;
  final String duration;
  final String packageValidTill;
  final int durationInDays;
  final int maxEntriesPerDay;
  final bool isActive;

  PackageData({
    required this.userId,
    required this.name,
    required this.email,
    required this.title,
    required this.price,
    required this.duration,
    required this.packageValidTill,
    required this.durationInDays,
    required this.maxEntriesPerDay,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'title': title,
      'price': price,
      'duration': duration,
      'packageValidTill': packageValidTill,
      'durationInDays': durationInDays,
      'maxEntriesPerDay': maxEntriesPerDay,
      'isActive': isActive ? 1 : 0,
    };
  }

  static PackageData fromMap(Map<String, dynamic> map) {
    return PackageData(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      title: map['title'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      duration: map['duration'] ?? '',
      packageValidTill: map['packageValidTill'], // optional
      durationInDays: map['durationInDays'] ?? 0,
      maxEntriesPerDay: map['maxEntriesPerDay'] ?? 0,
      isActive: (map['isActive'] == 1 || map['isActive'] == true),
    );
  }
}
