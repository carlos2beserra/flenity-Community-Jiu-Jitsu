// Modelos das respostas da API. Datas "date-only" chegam em UTC (meia-noite) e são mantidas em UTC.

typedef Json = Map<String, dynamic>;

DateTime? _date(Object? value) => value == null ? null : DateTime.parse(value as String);

class Ref {
  const Ref(this.id, this.name);

  factory Ref.fromJson(Json json) => Ref(json['id'] as String, json['name'] as String);
  static Ref? maybe(Object? json) => json == null ? null : Ref.fromJson(json as Json);

  final String id;
  final String name;
}

class StaffMe {
  const StaffMe({required this.id, required this.name, required this.role, required this.academyName});

  factory StaffMe.fromJson(Json json) => StaffMe(
        id: json['id'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        academyName: (json['academy'] as Json)['name'] as String,
      );

  final String id;
  final String name;
  final String role;
  final String academyName;

  String get roleLabel => const {'ADMIN': 'Administrador', 'INSTRUCTOR': 'Professor', 'RECEPTION': 'Recepção'}[role] ?? role;
}

/// Graduação atual + progresso até a próxima (linha do quadro de graduações).
class RankProgress {
  const RankProgress({
    required this.studentId,
    required this.studentName,
    required this.modalityId,
    required this.modalityName,
    required this.beltName,
    required this.beltColor,
    required this.degree,
    required this.maxDegrees,
    required this.minClasses,
    required this.classesSince,
    required this.promotedAt,
    required this.eligible,
  });

  factory RankProgress.fromJson(Json json) => RankProgress(
        studentId: json['studentId'] as String,
        studentName: json['studentName'] as String,
        modalityId: json['modalityId'] as String,
        modalityName: json['modalityName'] as String,
        beltName: json['beltName'] as String,
        beltColor: json['beltColor'] as String,
        degree: json['degree'] as int,
        maxDegrees: json['maxDegrees'] as int,
        minClasses: json['minClasses'] as int,
        classesSince: json['classesSince'] as int,
        promotedAt: _date(json['promotedAt'])!,
        eligible: json['eligible'] as bool,
      );

  final String studentId;
  final String studentName;
  final String modalityId;
  final String modalityName;
  final String beltName;
  final String beltColor;
  final int degree;
  final int maxDegrees;
  final int minClasses;
  final int classesSince;
  final DateTime promotedAt;
  final bool eligible;

  double get progress => minClasses == 0 ? 1 : (classesSince / minClasses).clamp(0, 1).toDouble();
  int get classesRemaining => (minClasses - classesSince).clamp(0, minClasses);
}

class Invoice {
  const Invoice({
    required this.id,
    required this.description,
    required this.amountCents,
    required this.dueDate,
    required this.status,
    this.paidAt,
    this.paymentMethod,
  });

  factory Invoice.fromJson(Json json) => Invoice(
        id: json['id'] as String,
        description: json['description'] as String,
        amountCents: json['amountCents'] as int,
        dueDate: _date(json['dueDate'])!,
        status: json['status'] as String,
        paidAt: _date(json['paidAt']),
        paymentMethod: json['paymentMethod'] as String?,
      );

  final String id;
  final String description;
  final int amountCents;
  final DateTime dueDate;
  final String status;
  final DateTime? paidAt;
  final String? paymentMethod;

  /// PAID | CANCELED | OVERDUE | PENDING, comparando com a data local de hoje.
  String stateOn(DateTime today) {
    if (status != 'PENDING') return status;
    final dueDay = DateTime.utc(dueDate.year, dueDate.month, dueDate.day);
    final todayDay = DateTime.utc(today.year, today.month, today.day);
    return dueDay.isBefore(todayDay) ? 'OVERDUE' : 'PENDING';
  }
}

class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.name,
    required this.academyName,
    required this.ranks,
    required this.classesThisMonth,
    required this.overdueCount,
    required this.overdueCents,
    required this.planNames,
    this.email,
    this.phone,
    this.birthDate,
    this.nextInvoice,
  });

  factory StudentProfile.fromJson(Json json) => StudentProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        birthDate: _date(json['birthDate']),
        academyName: (json['academy'] as Json)['name'] as String,
        ranks: (json['ranks'] as List).map((r) => RankProgress.fromJson(r as Json)).toList(),
        classesThisMonth: json['classesThisMonth'] as int,
        overdueCount: json['overdueCount'] as int,
        overdueCents: json['overdueCents'] as int,
        planNames: (json['memberships'] as List).map((m) => ((m as Json)['plan'] as Json)['name'] as String).toList(),
        nextInvoice: json['nextInvoice'] == null ? null : Invoice.fromJson(json['nextInvoice'] as Json),
      );

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final DateTime? birthDate;
  final String academyName;
  final List<RankProgress> ranks;
  final int classesThisMonth;
  final int overdueCount;
  final int overdueCents;
  final List<String> planNames;
  final Invoice? nextInvoice;
}

class ClassSlot {
  const ClassSlot({
    required this.id,
    required this.name,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    required this.modality,
    this.instructor,
    this.checkInOpen = false,
    this.checkedInToday = false,
    this.checkInsToday,
  });

  factory ClassSlot.fromJson(Json json) => ClassSlot(
        id: json['id'] as String,
        name: json['name'] as String,
        weekday: json['weekday'] as int,
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String,
        capacity: json['capacity'] as int,
        modality: Ref.fromJson(json['modality'] as Json),
        instructor: Ref.maybe(json['instructor']),
        checkInOpen: json['checkInOpen'] as bool? ?? false,
        checkedInToday: json['checkedInToday'] as bool? ?? false,
        checkInsToday: json['checkInsToday'] as int?,
      );

  final String id;
  final String name;
  final int weekday;
  final String startTime;
  final String endTime;
  final int capacity;
  final Ref modality;
  final Ref? instructor;
  final bool checkInOpen;
  final bool checkedInToday;
  final int? checkInsToday;
}

class CheckInEntry {
  const CheckInEntry({required this.id, required this.checkedAt, required this.modality, this.student, this.className});

  factory CheckInEntry.fromJson(Json json) => CheckInEntry(
        id: json['id'] as String,
        checkedAt: _date(json['checkedAt'])!,
        modality: json['modality'] == null ? null : Ref.fromJson(json['modality'] as Json),
        student: Ref.maybe(json['student']),
        className: (json['class'] as Json?)?['name'] as String?,
      );

  final String id;
  final DateTime checkedAt;
  final Ref? modality;
  final Ref? student;
  final String? className;
}

class StudentSummary {
  const StudentSummary({required this.id, required this.name, required this.status, this.phone, this.email});

  factory StudentSummary.fromJson(Json json) => StudentSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        status: json['status'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
      );

  final String id;
  final String name;
  final String status;
  final String? phone;
  final String? email;
}

/// Ficha do aluno vista pelo professor.
class StudentFile {
  const StudentFile({required this.summary, required this.ranks, required this.recentCheckIns, required this.invoices, this.notes});

  factory StudentFile.fromJson(Json json) {
    // Ranks vêm do mais recente para o mais antigo: o primeiro de cada modalidade é o atual.
    final seen = <String>{};
    final ranks = <CurrentRank>[];
    for (final raw in json['ranks'] as List) {
      final rank = CurrentRank.fromJson(raw as Json);
      if (seen.add(rank.modality.id)) ranks.add(rank);
    }
    return StudentFile(
      summary: StudentSummary.fromJson(json),
      notes: json['notes'] as String?,
      ranks: ranks,
      recentCheckIns: (json['checkIns'] as List).map((c) => CheckInEntry.fromJson(c as Json)).toList(),
      invoices: (json['invoices'] as List).map((i) => Invoice.fromJson(i as Json)).toList(),
    );
  }

  final StudentSummary summary;
  final String? notes;
  final List<CurrentRank> ranks;
  final List<CheckInEntry> recentCheckIns;
  final List<Invoice> invoices;
}

class CurrentRank {
  const CurrentRank({required this.modality, required this.beltName, required this.beltColor, required this.degree, required this.promotedAt});

  factory CurrentRank.fromJson(Json json) {
    final belt = json['belt'] as Json;
    return CurrentRank(
      modality: Ref.fromJson(json['modality'] as Json),
      beltName: belt['name'] as String,
      beltColor: belt['color'] as String,
      degree: json['degree'] as int,
      promotedAt: _date(json['promotedAt'])!,
    );
  }

  final Ref modality;
  final String beltName;
  final String beltColor;
  final int degree;
  final DateTime promotedAt;
}
