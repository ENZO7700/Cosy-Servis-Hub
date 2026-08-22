class IsarOfflineQueue {
  int? isarId;
  String? operation;
  String? bugId;
  String? payload;
  DateTime? createdAt;
}

class IsarClientTask {
  String? id;
  String? text;
  bool? done;
  String? dueDate;
  DateTime? createdAt;
  DateTime? updatedAt;
}

class IsarClient {
  int? isarId;
  String? id;
  String? companyName;
  String? contactName;
  String? email;
  String? phone;
  String? website;
  String? service;
  String? status;
  String? budget;
  String? notes;
  List<IsarClientTask>? tasks;
  DateTime? createdAt;
  DateTime? updatedAt;
  DateTime? deletedAt;
  String? syncStatus;
}

class IsarClientActivity {
  int? isarId;
  String? id;
  String? clientId;
  String? type;
  String? title;
  String? content;
  DateTime? createdAt;
}
