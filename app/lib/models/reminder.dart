class Reminder {
  String title;
  DateTime deadline;
  bool isDone;

  Reminder({
    required this.title,
    required this.deadline,
    this.isDone = false,
  });
}