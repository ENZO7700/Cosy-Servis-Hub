import '../../../core/database/isar_models.dart'
    if (dart.library.html) '../../../core/database/isar_models_web.dart';

class CrmClientTask {
  final String id;
  final String text;
  final bool done;
  final String? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  CrmClientTask({
    required this.id,
    required this.text,
    required this.done,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CrmClientTask.fromIsar(IsarClientTask isar) {
    return CrmClientTask(
      id: isar.id ?? '',
      text: isar.text ?? '',
      done: isar.done ?? false,
      dueDate: isar.dueDate,
      createdAt: isar.createdAt ?? DateTime.now(),
      updatedAt: isar.updatedAt ?? DateTime.now(),
    );
  }

  IsarClientTask toIsar() {
    return IsarClientTask()
      ..id = id
      ..text = text
      ..done = done
      ..dueDate = dueDate
      ..createdAt = createdAt
      ..updatedAt = updatedAt;
  }

  factory CrmClientTask.fromJson(Map<String, dynamic> json) {
    return CrmClientTask(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      done: json['done'] ?? false,
      dueDate: json['dueDate'],
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'done': done,
      'dueDate': dueDate,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class CrmClient {
  final String id;
  final String companyName;
  final String? contactName;
  final String? email;
  final String? phone;
  final String? website;
  final String service;
  final String status;
  final String? budget;
  final String? notes;
  final List<CrmClientTask> tasks;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String syncStatus; // 'synced' | 'pending' | 'error'

  CrmClient({
    required this.id,
    required this.companyName,
    this.contactName,
    this.email,
    this.phone,
    this.website,
    required this.service,
    required this.status,
    this.budget,
    this.notes,
    required this.tasks,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.syncStatus,
  });

  factory CrmClient.fromIsar(IsarClient isar) {
    return CrmClient(
      id: isar.id ?? '',
      companyName: isar.companyName ?? '',
      contactName: isar.contactName,
      email: isar.email,
      phone: isar.phone,
      website: isar.website,
      service: isar.service ?? 'Web stránka',
      status: isar.status ?? 'Lead',
      budget: isar.budget,
      notes: isar.notes,
      tasks: (isar.tasks ?? []).map((t) => CrmClientTask.fromIsar(t)).toList(),
      createdAt: isar.createdAt ?? DateTime.now(),
      updatedAt: isar.updatedAt ?? DateTime.now(),
      deletedAt: isar.deletedAt,
      syncStatus: isar.syncStatus ?? 'synced',
    );
  }

  IsarClient toIsar() {
    return IsarClient()
      ..id = id
      ..companyName = companyName
      ..contactName = contactName
      ..email = email
      ..phone = phone
      ..website = website
      ..service = service
      ..status = status
      ..budget = budget
      ..notes = notes
      ..tasks = tasks.map((t) => t.toIsar()).toList()
      ..createdAt = createdAt
      ..updatedAt = updatedAt
      ..deletedAt = deletedAt
      ..syncStatus = syncStatus;
  }

  factory CrmClient.fromJson(Map<String, dynamic> json) {
    return CrmClient(
      id: json['id'] ?? '',
      companyName: json['companyName'] ?? '',
      contactName: json['contactName'],
      email: json['email'],
      phone: json['phone'],
      website: json['website'],
      service: json['service'] ?? 'Web stránka',
      status: json['status'] ?? 'Lead',
      budget: json['budget'],
      notes: json['notes'],
      tasks:
          (json['tasks'] as List<dynamic>?)
              ?.map((t) => CrmClientTask.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'])
          : null,
      syncStatus: json['syncStatus'] ?? 'synced',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyName': companyName,
      'contactName': contactName,
      'email': email,
      'phone': phone,
      'website': website,
      'service': service,
      'status': status,
      'budget': budget,
      'notes': notes,
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'syncStatus': syncStatus,
    };
  }

  CrmClient copyWith({
    String? id,
    String? companyName,
    String? contactName,
    String? email,
    String? phone,
    String? website,
    String? service,
    String? status,
    String? budget,
    String? notes,
    List<CrmClientTask>? tasks,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? syncStatus,
  }) {
    return CrmClient(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      contactName: contactName ?? this.contactName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      service: service ?? this.service,
      status: status ?? this.status,
      budget: budget ?? this.budget,
      notes: notes ?? this.notes,
      tasks: tasks ?? this.tasks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class CrmClientActivity {
  final String id;
  final String clientId;
  final String
  type; // 'note' | 'call' | 'email' | 'meeting' | 'proposal' | 'status_change'
  final String title;
  final String? content;
  final DateTime createdAt;

  CrmClientActivity({
    required this.id,
    required this.clientId,
    required this.type,
    required this.title,
    this.content,
    required this.createdAt,
  });

  factory CrmClientActivity.fromIsar(IsarClientActivity isar) {
    return CrmClientActivity(
      id: isar.id ?? '',
      clientId: isar.clientId ?? '',
      type: isar.type ?? 'note',
      title: isar.title ?? '',
      content: isar.content,
      createdAt: isar.createdAt ?? DateTime.now(),
    );
  }

  IsarClientActivity toIsar() {
    return IsarClientActivity()
      ..id = id
      ..clientId = clientId
      ..type = type
      ..title = title
      ..content = content
      ..createdAt = createdAt;
  }

  factory CrmClientActivity.fromJson(Map<String, dynamic> json) {
    return CrmClientActivity(
      id: json['id'] ?? '',
      clientId: json['clientId'] ?? '',
      type: json['type'] ?? 'note',
      title: json['title'] ?? '',
      content: json['content'],
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'type': type,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
