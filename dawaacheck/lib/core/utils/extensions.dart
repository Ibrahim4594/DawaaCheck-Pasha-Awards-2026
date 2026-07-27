import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_strings.dart';

extension DateTimeX on DateTime {
  String get timeAgo {
    final diff = DateTime.now().difference(this);
    if (diff.inDays > 30) return DateFormat('MMM d, yyyy').format(this);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  String get formatted => DateFormat('MMM d, yyyy').format(this);
  String get formattedWithTime => DateFormat('MMM d, yyyy — h:mm a').format(this);
}

extension StringX on String {
  String get capitalize => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

extension ContextX on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  EdgeInsets get padding => MediaQuery.of(this).padding;
}

extension TimeOfDayGreeting on DateTime {
  String get greeting {
    final hour = this.hour;
    if (hour < 5) return AppStrings.goodNight;
    if (hour < 12) return AppStrings.goodMorning;
    if (hour < 17) return AppStrings.goodAfternoon;
    if (hour < 21) return AppStrings.goodEvening;
    return AppStrings.goodNight;
  }
}
