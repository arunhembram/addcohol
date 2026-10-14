import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

/// Supported daily photo verification states
enum ShopPhotoState {
  notUploaded,
  pendingReview,
  approved,
  rejected,
  expired,
}

/// Operational status categories for a shop during the current business day
enum ShopOperationalType {
  closedToday,
  beforeOpening,
  openPhotoMissingGrace,
  openPhotoDelayed,
  photoUploaded,
  followupScheduled,
  followupToday,
  followupMissed,
  underProcess,
}

/// Rich operational status for a shop based on server business date,
/// Asia/Kolkata timezone, opening/closing schedule, and photo uploads.
class ShopOperationalStatus {
  final Shop shop;
  final ShopPhotoState photoState;
  final ShopOperationalType operationalType;
  final ShopDailyUpload? dailyUpload;
  final Duration? countdownToOpen;
  final Duration? photoDelayDuration;
  final int gracePeriodMinutes;
  final DateTime calculationTime;

  const ShopOperationalStatus({
    required this.shop,
    required this.photoState,
    required this.operationalType,
    this.dailyUpload,
    this.countdownToOpen,
    this.photoDelayDuration,
    this.gracePeriodMinutes = 15,
    required this.calculationTime,
  });

  /// Primary English status label
  String get badgeText {
    switch (operationalType) {
      case ShopOperationalType.closedToday:
        if (CanonicalShops.isShopClosedToday(shop.id)) {
          return 'Closed today (Visited)';
        }
        if (ShopOperationalService.isWeeklyClosed(shop, calculationTime)) {
          return 'Closed today (Weekly off)';
        }
        return 'Closed today';
      case ShopOperationalType.beforeOpening:
        if (countdownToOpen != null) {
          return 'Opening in ${ShopOperationalService.formatCountdown(countdownToOpen!)}';
        }
        return 'Before opening';
      case ShopOperationalType.openPhotoMissingGrace:
        final remainingMins = (gracePeriodMinutes -
                (photoDelayDuration?.inMinutes ?? 0))
            .clamp(0, gracePeriodMinutes);
        return 'Photo pending (Grace period: ${remainingMins}m)';
      case ShopOperationalType.openPhotoDelayed:
        if (photoDelayDuration != null) {
          return 'Photo pending • delayed by ${ShopOperationalService.formatDelay(photoDelayDuration!)}';
        }
        return 'Photo pending • delayed';
      case ShopOperationalType.photoUploaded:
        switch (photoState) {
          case ShopPhotoState.approved:
            return 'Photo Approved';
          case ShopPhotoState.pendingReview:
            return 'Pending Review';
          case ShopPhotoState.rejected:
            return 'Photo Rejected';
          case ShopPhotoState.expired:
            return 'Photo Expired';
          case ShopPhotoState.notUploaded:
            return 'Photo Not Uploaded';
        }
      case ShopOperationalType.followupMissed:
        return 'Follow-up Missed (Overdue)';
      case ShopOperationalType.followupToday:
        return 'Follow-up Scheduled Today';
      case ShopOperationalType.followupScheduled:
        return 'Follow-up Scheduled';
      case ShopOperationalType.underProcess:
        return 'Under Process';
    }
  }

  /// Bengali status translation
  String get bengaliBadgeText {
    switch (operationalType) {
      case ShopOperationalType.closedToday:
        if (CanonicalShops.isShopClosedToday(shop.id)) {
          return 'আজ বন্ধ (পরিদর্শিত)';
        }
        if (ShopOperationalService.isWeeklyClosed(shop, calculationTime)) {
          return 'আজ বন্ধ (সাপ্তাহিক ছুটি)';
        }
        return 'আজ বন্ধ';
      case ShopOperationalType.beforeOpening:
        if (countdownToOpen != null) {
          return 'খোলার বাকি ${ShopOperationalService.formatCountdown(countdownToOpen!)}';
        }
        return 'এখনো খোলেনি';
      case ShopOperationalType.openPhotoMissingGrace:
        return 'ছবি বাকি (গ্রেস পিরিয়ড)';
      case ShopOperationalType.openPhotoDelayed:
        if (photoDelayDuration != null) {
          return 'ছবি বাকি • বিলম্ব ${ShopOperationalService.formatDelay(photoDelayDuration!)}';
        }
        return 'ছবি বাকি • বিলম্বিত';
      case ShopOperationalType.photoUploaded:
        switch (photoState) {
          case ShopPhotoState.approved:
            return 'অনুমোদিত';
          case ShopPhotoState.pendingReview:
            return 'পর্যালোচনা বাকি';
          case ShopPhotoState.rejected:
            return 'প্রত্যাখ্যাত';
          case ShopPhotoState.expired:
            return 'মেয়াদোত্তীর্ণ';
          case ShopPhotoState.notUploaded:
            return 'ছবি নেই';
        }
      case ShopOperationalType.followupMissed:
        return 'ফলো-আপ মিসড (দেরি হয়ে গেছে)';
      case ShopOperationalType.followupToday:
        return 'আজকে ফলো-আপ';
      case ShopOperationalType.followupScheduled:
        return 'ফলো-আপ নির্ধারিত';
      case ShopOperationalType.underProcess:
        return 'অনুমোদনাধীন (Under Process)';
    }
  }

  /// Theme color for status badges, pins, and borders
  Color get statusColor {
    switch (operationalType) {
      case ShopOperationalType.closedToday:
        return const Color(0xFFE65100); // Orange matching Closed Today button
      case ShopOperationalType.beforeOpening:
        return const Color(0xFFF59E0B); // Amber
      case ShopOperationalType.openPhotoMissingGrace:
        return const Color(0xFFF97316); // Orange
      case ShopOperationalType.openPhotoDelayed:
        return const Color(0xFFEA580C); // Deep Orange / Red-Orange
      case ShopOperationalType.photoUploaded:
        switch (photoState) {
          case ShopPhotoState.approved:
            return const Color(0xFF16A34A); // Emerald Green
          case ShopPhotoState.pendingReview:
            return const Color(0xFF0284C7); // Sky Blue
          case ShopPhotoState.rejected:
            return const Color(0xFFDC2626); // Red
          case ShopPhotoState.expired:
            return const Color(0xFF6B7280); // Grey
          case ShopPhotoState.notUploaded:
            return const Color(0xFFF97316);
        }
      case ShopOperationalType.followupMissed:
        return const Color(0xFFEF4444); // Error Red
      case ShopOperationalType.followupToday:
        return const Color(0xFFFB8C00); // Orange
      case ShopOperationalType.followupScheduled:
        return const Color(0xFF1E88E5); // Blue
      case ShopOperationalType.underProcess:
        return const Color(0xFFF59E0B); // Amber
    }
  }

  /// Icon representing the status
  IconData get statusIcon {
    switch (operationalType) {
      case ShopOperationalType.closedToday:
        return Icons.lock_clock;
      case ShopOperationalType.beforeOpening:
        return Icons.hourglass_top_rounded;
      case ShopOperationalType.openPhotoMissingGrace:
        return Icons.timer_outlined;
      case ShopOperationalType.openPhotoDelayed:
        return Icons.warning_amber_rounded;
      case ShopOperationalType.photoUploaded:
        switch (photoState) {
          case ShopPhotoState.approved:
            return Icons.check_circle_rounded;
          case ShopPhotoState.pendingReview:
            return Icons.schedule_rounded;
          case ShopPhotoState.rejected:
            return Icons.cancel_rounded;
          case ShopPhotoState.expired:
            return Icons.event_busy_rounded;
          case ShopPhotoState.notUploaded:
            return Icons.photo_camera_back_outlined;
        }
      case ShopOperationalType.followupMissed:
        return Icons.warning_rounded;
      case ShopOperationalType.followupToday:
        return Icons.notifications_active_rounded;
      case ShopOperationalType.followupScheduled:
        return Icons.event_note_rounded;
      case ShopOperationalType.underProcess:
        return Icons.hourglass_top_rounded;
    }
  }

  /// Google Map Marker hue
  double get markerHue {
    switch (operationalType) {
      case ShopOperationalType.closedToday:
        return 270.0; // Violet
      case ShopOperationalType.beforeOpening:
        return 45.0; // Yellow-Amber
      case ShopOperationalType.openPhotoMissingGrace:
        return 35.0; // Orange
      case ShopOperationalType.openPhotoDelayed:
        return 25.0; // Deep Orange
      case ShopOperationalType.photoUploaded:
        switch (photoState) {
          case ShopPhotoState.approved:
            return 120.0; // Green
          case ShopPhotoState.pendingReview:
            return 195.0; // Azure / Sky Blue
          case ShopPhotoState.rejected:
            return 0.0; // Red
          case ShopPhotoState.expired:
            return 300.0; // Magenta / Grey tint
          case ShopPhotoState.notUploaded:
            return 35.0;
        }
      case ShopOperationalType.followupMissed:
        return 30.0; // Orange
      case ShopOperationalType.followupToday:
        return 30.0; // Orange
      case ShopOperationalType.followupScheduled:
        return 210.0; // Azure / Blue
      case ShopOperationalType.underProcess:
        return 40.0; // Amber
    }
  }
}

/// Service providing Asia/Kolkata timezone calculations, opening countdowns,
/// photo grace periods, and status evaluation.
class ShopOperationalService {
  /// Asia/Kolkata is UTC+05:30
  static const Duration kolkataOffset = Duration(hours: 5, minutes: 30);

  /// Convert any reference time or current UTC clock to Asia/Kolkata DateTime
  static DateTime getKolkataNow([DateTime? referenceTime]) {
    final utc = (referenceTime ?? DateTime.now()).toUtc();
    return utc.add(kolkataOffset);
  }

  /// Get current business date in YYYY-MM-DD string using Asia/Kolkata
  static String getKolkataBusinessDate([DateTime? referenceTime]) {
    final ist = getKolkataNow(referenceTime);
    final y = ist.year.toString().padLeft(4, '0');
    final m = ist.month.toString().padLeft(2, '0');
    final d = ist.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Check if today is the shop's weekly closed day
  static bool isWeeklyClosed(Shop shop, [DateTime? referenceTime]) =>
      shop.isWeeklyClosedToday(referenceTime);

  /// Parse a shop's opening time string (e.g. "09:00 AM", "6 PM", "6:00 PM", "18:00")
  /// into a DateTime on the target Kolkata date.
  static DateTime? parseOpeningTime(String? timeStr, [DateTime? referenceTime]) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;

    final ist = getKolkataNow(referenceTime);
    final clean = timeStr.trim().toUpperCase();

    // Match 12-hour format e.g. "09:00 AM", "6 PM", "6:00 PM", "6PM"
    final match12 =
        RegExp(r'^(\d{1,2})(?::(\d{2}))?(?::\d{2})?\s*(AM|PM)$').firstMatch(clean);
    if (match12 != null) {
      int hour = int.parse(match12.group(1)!);
      final minute =
          match12.group(2) != null ? int.parse(match12.group(2)!) : 0;
      final period = match12.group(3)!;

      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;

      return DateTime.utc(ist.year, ist.month, ist.day, hour, minute);
    }

    // Match 24-hour format e.g. "09:00" or "21:30"
    final match24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(clean);
    if (match24 != null) {
      final hour = int.parse(match24.group(1)!);
      final minute = int.parse(match24.group(2)!);
      return DateTime.utc(ist.year, ist.month, ist.day, hour, minute);
    }

    return null;
  }

  /// Calculate full operational and photo status for a shop
  static ShopOperationalStatus calculateStatus({
    required Shop shop,
    ShopDailyUpload? todayUpload,
    DateTime? referenceTime,
    int gracePeriodMinutes = 15,
  }) {
    final nowIst = getKolkataNow(referenceTime);

    // 0. Under Process Handling (Newly created shops pending admin approval)
    if (shop.isUnderProcess) {
      return ShopOperationalStatus(
        shop: shop,
        photoState: ShopPhotoState.notUploaded,
        operationalType: ShopOperationalType.underProcess,
        gracePeriodMinutes: gracePeriodMinutes,
        calculationTime: nowIst,
      );
    }

    // 0.5 Follow-up Lead Handling (Precedence when shop is saved for follow-up)
    if (shop.isFollowup) {
      if (shop.isFollowupMissed) {
        return ShopOperationalStatus(
          shop: shop,
          photoState: ShopPhotoState.notUploaded,
          operationalType: ShopOperationalType.followupMissed,
          gracePeriodMinutes: gracePeriodMinutes,
          calculationTime: nowIst,
        );
      } else if (shop.isFollowupToday) {
        return ShopOperationalStatus(
          shop: shop,
          photoState: ShopPhotoState.notUploaded,
          operationalType: ShopOperationalType.followupToday,
          gracePeriodMinutes: gracePeriodMinutes,
          calculationTime: nowIst,
        );
      } else {
        return ShopOperationalStatus(
          shop: shop,
          photoState: ShopPhotoState.notUploaded,
          operationalType: ShopOperationalType.followupScheduled,
          gracePeriodMinutes: gracePeriodMinutes,
          calculationTime: nowIst,
        );
      }
    }

    // 1. Manually Marked Closed Today by Employee or Weekly Closed Day or Inactive Shop
    if (CanonicalShops.isShopClosedToday(shop.id) || isWeeklyClosed(shop, referenceTime)) {
      return ShopOperationalStatus(
        shop: shop,
        photoState: todayUpload != null
            ? _mapUploadToPhotoState(todayUpload, nowIst)
            : ShopPhotoState.notUploaded,
        operationalType: ShopOperationalType.closedToday,
        dailyUpload: todayUpload,
        gracePeriodMinutes: gracePeriodMinutes,
        calculationTime: nowIst,
      );
    }

    // 2. Photo Uploaded Check (Takes precedence when today's photo is present)
    if (todayUpload != null) {
      final photoState = _mapUploadToPhotoState(todayUpload, nowIst);
      return ShopOperationalStatus(
        shop: shop,
        photoState: photoState,
        operationalType: ShopOperationalType.photoUploaded,
        dailyUpload: todayUpload,
        gracePeriodMinutes: gracePeriodMinutes,
        calculationTime: nowIst,
      );
    }

    // 3. Before Opening Time Check (When photo is not yet uploaded)
    final openingIst = parseOpeningTime(shop.openingTime, referenceTime);
    if (openingIst != null && nowIst.isBefore(openingIst)) {
      final remaining = openingIst.difference(nowIst);
      return ShopOperationalStatus(
        shop: shop,
        photoState: ShopPhotoState.notUploaded,
        operationalType: ShopOperationalType.beforeOpening,
        dailyUpload: null,
        countdownToOpen: remaining,
        gracePeriodMinutes: gracePeriodMinutes,
        calculationTime: nowIst,
      );
    }

    // 4. Shop is open, but today's photo is missing:
    // Check configurable grace period (default 15 minutes)
    final effectiveOpening = openingIst ?? DateTime.utc(nowIst.year, nowIst.month, nowIst.day, 8, 0);
    final elapsedSinceOpening = nowIst.difference(effectiveOpening);

    if (elapsedSinceOpening.inMinutes < gracePeriodMinutes) {
      // Still inside grace period
      return ShopOperationalStatus(
        shop: shop,
        photoState: ShopPhotoState.notUploaded,
        operationalType: ShopOperationalType.openPhotoMissingGrace,
        photoDelayDuration: elapsedSinceOpening,
        gracePeriodMinutes: gracePeriodMinutes,
        calculationTime: nowIst,
      );
    } else {
      // Grace period expired — Photo is delayed!
      // Delay duration from opening time (or from grace period end)
      final delayedDuration = elapsedSinceOpening;
      return ShopOperationalStatus(
        shop: shop,
        photoState: ShopPhotoState.notUploaded,
        operationalType: ShopOperationalType.openPhotoDelayed,
        photoDelayDuration: delayedDuration,
        gracePeriodMinutes: gracePeriodMinutes,
        calculationTime: nowIst,
      );
    }
  }

  static ShopPhotoState _mapUploadToPhotoState(
      ShopDailyUpload upload, DateTime nowIst) {
    if (upload.isExpired || upload.expiryTime.isBefore(nowIst)) {
      return ShopPhotoState.expired;
    }
    final status = upload.verificationStatus.toLowerCase();
    if (status == 'verified' || status == 'approved') {
      return ShopPhotoState.approved;
    }
    if (status == 'rejected' || status == 'flagged') {
      return ShopPhotoState.rejected;
    }
    return ShopPhotoState.pendingReview;
  }

  /// Format countdown in DD:HH:MM:SS (e.g. "00D:05H:20M:10S" or "2D:5H:20M:10S")
  static String formatCountdown(Duration duration) {
    final totalSeconds = duration.inSeconds.abs();
    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final dStr = days.toString().padLeft(2, '0');
    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    if (days > 0) {
      return '${days}D:$hStr:$mStr:$sStr';
    }
    return '$dStr:$hStr:$mStr:$sStr';
  }

  /// Format delay in HH:MM (e.g. "00H:35M")
  static String formatDelay(Duration duration) {
    final totalMinutes = duration.inMinutes.abs();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    return '${hStr}H:${mStr}M';
  }
}
