import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final DateFormat _defaultFormat = DateFormat('dd/MM/yyyy HH:mm');

  static String formatDefault(DateTime value) {
    return _defaultFormat.format(value);
  }
}
