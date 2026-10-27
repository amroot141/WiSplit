import 'dart:convert';

class GroupModel {
  final String id;
  final String name;
  final String description;
  final String currency;
  final String createdBy;
  final List<String> members;
  final DateTime createdAt;

  List<String> get memberIds => members;

  const GroupModel({
    required this.id,
    required this.name,
    this.description = '',
    this.currency = 'INR',
    required this.createdBy,
    required this.members,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'currency': currency,
      'created_by': createdBy,
      'members_json': jsonEncode(members),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    List<String> memberList = [];
    if (map['members_json'] != null) {
      try {
        final decoded = jsonDecode(map['members_json'] as String);
        if (decoded is List) {
          memberList = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    } else if (map['members'] is List) {
      memberList = (map['members'] as List).map((e) => e.toString()).toList();
    }

    return GroupModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      currency: (map['currency'] as String?) ?? 'INR',
      createdBy: (map['created_by'] as String?) ?? '',
      members: memberList,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? currency,
    String? createdBy,
    List<String>? members,
    DateTime? createdAt,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      currency: currency ?? this.currency,
      createdBy: createdBy ?? this.createdBy,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
