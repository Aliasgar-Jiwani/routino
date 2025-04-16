import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class TimetableEntry extends HiveObject {
  final String day;
  final String taskName;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String? notes;

  TimetableEntry({
    required this.day,
    required this.taskName,
    required this.startTime,
    required this.endTime,
    this.notes,
  });
}

class TimetableEntryAdapter extends TypeAdapter<TimetableEntry> {
  @override
  final int typeId = 0;

  @override
  TimetableEntry read(BinaryReader reader) {
    final day = reader.read() as String;
    final taskName = reader.read() as String;
    final startHour = reader.read() as int;
    final startMinute = reader.read() as int;
    final endHour = reader.read() as int;
    final endMinute = reader.read() as int;
    final notes = reader.read() as String?;
    return TimetableEntry(
      day: day,
      taskName: taskName,
      startTime: TimeOfDay(hour: startHour, minute: startMinute),
      endTime: TimeOfDay(hour: endHour, minute: endMinute),
      notes: notes,
    );
  }

  @override
  void write(BinaryWriter writer, TimetableEntry obj) {
    writer.write(obj.day);
    writer.write(obj.taskName);
    writer.write(obj.startTime.hour);
    writer.write(obj.startTime.minute);
    writer.write(obj.endTime.hour);
    writer.write(obj.endTime.minute);
    writer.write(obj.notes);
  }
}
