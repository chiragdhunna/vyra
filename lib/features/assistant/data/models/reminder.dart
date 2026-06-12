/// A scheduled reminder. [id] doubles as the local-notification id, so it is
/// kept within a 32-bit range when created.
class Reminder {
  final int id;
  final String title;
  final DateTime time;
  final bool done;

  const Reminder({
    required this.id,
    required this.title,
    required this.time,
    this.done = false,
  });

  Reminder copyWith({String? title, DateTime? time, bool? done}) => Reminder(
        id: id,
        title: title ?? this.title,
        time: time ?? this.time,
        done: done ?? this.done,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'time': time.millisecondsSinceEpoch,
        'done': done,
      };

  factory Reminder.fromMap(Map map) => Reminder(
        id: (map['id'] as num).toInt(),
        title: (map['title'] as String?) ?? '',
        time: DateTime.fromMillisecondsSinceEpoch(
          (map['time'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
        ),
        done: (map['done'] as bool?) ?? false,
      );

  bool get isPast => time.isBefore(DateTime.now());
}
