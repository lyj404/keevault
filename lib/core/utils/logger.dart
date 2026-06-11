import 'package:logger/logger.dart';

final log = Logger(
  printer: PrettyPrinter(methodCount: 0, dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart),
);
