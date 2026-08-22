class Profile {
  final String id;
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final String? jobTitle;
  final DateTime createdAt;
  final DateTime updatedAt;

  Profile({
    required this.id,
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    this.jobTitle,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      fullName: map['full_name'] ?? '',
      avatarUrl: map['avatar_url'],
      jobTitle: map['job_title'],
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'job_title': jobTitle,
    };
  }
}

class Project {
  final String id;
  final String name;
  final String? description;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.id,
    required this.name,
    this.description,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      createdBy: map['created_by'],
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_by': createdBy,
    };
  }
}

class Bug {
  final String id;
  final String trackingId;
  final String title;
  final String description;
  final String? projectId;
  final String? assigneeId;
  final String reporterId;
  final String severity; // critical, high, medium, low
  final String status; // new, assigned, in_progress, testing, resolved, closed
  final String? stepsToReproduce;
  final String? expectedBehavior;
  final String? actualBehavior;
  final String? environment;
  final DateTime createdAt;
  final DateTime updatedAt;

  Bug({
    required this.id,
    required this.trackingId,
    required this.title,
    required this.description,
    this.projectId,
    this.assigneeId,
    required this.reporterId,
    required this.severity,
    required this.status,
    this.stepsToReproduce,
    this.expectedBehavior,
    this.actualBehavior,
    this.environment,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Bug.fromMap(Map<String, dynamic> map) {
    return Bug(
      id: map['id'] ?? '',
      trackingId: map['tracking_id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      projectId: map['project_id'],
      assigneeId: map['assignee_id'],
      reporterId: map['reporter_id'] ?? '',
      severity: map['severity'] ?? 'low',
      status: map['status'] ?? 'new',
      stepsToReproduce: map['steps_to_reproduce'],
      expectedBehavior: map['expected_behavior'],
      actualBehavior: map['actual_behavior'],
      environment: map['environment'],
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'tracking_id': trackingId,
      'title': title,
      'description': description,
      'project_id': projectId,
      'assignee_id': assigneeId,
      'reporter_id': reporterId,
      'severity': severity,
      'status': status,
      'steps_to_reproduce': stepsToReproduce,
      'expected_behavior': expectedBehavior,
      'actual_behavior': actualBehavior,
      'environment': environment,
    };
  }
}

class AiConversation {
  final String id;
  final String title;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  AiConversation({
    required this.id,
    required this.title,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiConversation.fromMap(Map<String, dynamic> map) {
    return AiConversation(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      userId: map['user_id'] ?? '',
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class AiMessage {
  final String id;
  final String conversationId;
  final String content;
  final String role; // user, assistant
  final String userId;
  final DateTime createdAt;

  AiMessage({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.role,
    required this.userId,
    required this.createdAt,
  });

  factory AiMessage.fromMap(Map<String, dynamic> map) {
    return AiMessage(
      id: map['id'] ?? '',
      conversationId: map['conversation_id'] ?? '',
      content: map['content'] ?? '',
      role: map['role'] ?? 'user',
      userId: map['user_id'] ?? '',
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'conversation_id': conversationId,
      'content': content,
      'role': role,
      'user_id': userId,
    };
  }
}

class AppUser {
  final String uid;
  final String? email;

  AppUser({required this.uid, this.email});
}
