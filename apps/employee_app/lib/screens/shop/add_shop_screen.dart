import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/employee_state_providers.dart';

/// ============================================================================
/// THEME DESIGN TOKENS
/// Clean, Modern Light Theme for Field-Agent Portal
/// ============================================================================
class AddShopTheme {
  // Surfaces & Backgrounds
  static const Color pageBackground = Color(0xFFF6F8FB);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE6EAF0);
  static const Color inputBorder = Color(0xFFD1D5DB);
  static const Color inputBorderFocused = Color(0xFF0F9D8A);

  // Primary Brand Colors (Vibrant Teal / Emerald)
  static const Color primaryTeal = Color(0xFF0F9D8A);
  static const Color primaryTealDark = Color(0xFF0C8272);
  static const Color primaryTealLight = Color(0xFFE6F6F3);
  static const Color primaryTealGlow = Color(0x330F9D8A);

  // Accent & Status Colors (Warm Orange, Success Green, Error Red)
  static const Color accentOrange = Color(0xFFFF8A3D);
  static const Color accentOrangeDark = Color(0xFFE67329);
  static const Color accentOrangeLight = Color(0xFFFFF3EB);
  static const Color successGreen = Color(0xFF10B981);
  static const Color successGreenLight = Color(0xFFECFDF5);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color errorRedLight = Color(0xFFFEF2F2);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color warningAmberLight = Color(0xFFFFFBEB);

  // Typography Colors (WCAG AA Compliant)
  static const Color textDarkSlate = Color(0xFF1F2937);
  static const Color textBody = Color(0xFF374151);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textPlaceholder = Color(0xFF9CA3AF);

  // Metrics & Radii
  static const double radiusCard = 16.0;
  static const double radiusInput = 12.0;
  static const double radiusButton = 12.0;
  static const double radiusPill = 99.0;

  // Elevation & Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(16, 24, 40, 0.06),
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> stickyBottomShadow = [
    BoxShadow(
      color: Color.fromRGBO(16, 24, 40, 0.08),
      blurRadius: 16,
      offset: Offset(0, -4),
    ),
  ];

  static const List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: Color.fromRGBO(15, 157, 138, 0.25),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
}

class AddShopScreen extends ConsumerStatefulWidget {
  final String? zoneId;
  final String? zoneName;
  final double? latitude;
  final double? longitude;
  final String? initialCategory;

  const AddShopScreen({
    super.key,
    this.zoneId,
    this.zoneName,
    this.latitude,
    this.longitude,
    this.initialCategory,
  });

  @override
  ConsumerState<AddShopScreen> createState() => _AddShopScreenState();
}

class _AddShopScreenState extends ConsumerState<AddShopScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _ownerNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _followupReasonController = TextEditingController();

  String _selectedCategory = ShopCategory.grocery.displayName;
  int? _agreedOpeningHour12;
  String? _agreedOpeningPeriod;
  String _openingTime = '';
  String _closingTime = '09:00 PM';
  String _weeklyClosedDay = 'None';
  Uint8List? _capturedPhotoBytes;
  bool _isAgreed = true; // true = Agreed & Active, false = Needs Follow-up
  DateTime? _selectedFollowupDate;
  DateTime _followupDateTime = DateTime.now().add(const Duration(days: 1));
  int? _selectedHour12;
  String? _selectedPeriod; // 'sokal', 'dupur', 'bikel', 'sondhya', 'rat'
  final ScrollController _dateScrollController = ScrollController();
  bool _showRightDateArrow = true;

  bool _isSubmitting = false;
  String? _duplicatePhoneWarning;
  List<Shop> _nearbyDuplicateShops = [];

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<Map<String, String>> _bengaliWeeklyClosedOptions = const [
    {'id': 'None', 'label': 'কোনো বন্ধ নেই'},
    {'id': 'Sunday', 'label': 'রবি'},
    {'id': 'Monday', 'label': 'সোম'},
    {'id': 'Tuesday', 'label': 'মঙ্গল'},
    {'id': 'Wednesday', 'label': 'বুধ'},
    {'id': 'Thursday', 'label': 'বৃহস্পতি'},
    {'id': 'Friday', 'label': 'শুক্র'},
    {'id': 'Saturday', 'label': 'শনি'},
  ];

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _followupDateTime = DateTime(now.year, now.month, now.day + 1, 10, 0);
    _selectedFollowupDate = null;
    _selectedHour12 = null;
    _selectedPeriod = null;
    _agreedOpeningHour12 = null;
    _agreedOpeningPeriod = null;
    _openingTime = '';

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();

    if (widget.initialCategory != null &&
        widget.initialCategory!.trim().isNotEmpty) {
      final matchedCat = ShopCategory.fromString(widget.initialCategory);
      _selectedCategory = matchedCat.displayName;
    }
    _checkNearbyDuplicates();
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    _animController.dispose();
    _ownerNameController.dispose();
    _phoneNumberController.dispose();
    _shopNameController.dispose();
    _landmarkController.dispose();
    _photoUrlController.dispose();
    _followupReasonController.dispose();
    super.dispose();
  }

  void _checkNearbyDuplicates() async {
    if (widget.latitude == null || widget.longitude == null) return;
    try {
      final repo = ref.read(employeeRepositoryProvider);
      final empId = ref.read(currentEmployeeIdProvider);
      final nearby = await repo.getNearbyDuplicateShops(
        employeeId: empId,
        latitude: widget.latitude!,
        longitude: widget.longitude!,
        thresholdMeters: 20.0,
      );
      if (mounted) {
        setState(() {
          _nearbyDuplicateShops = nearby;
        });
      }
    } catch (_) {}
  }

  void _onPhoneChanged(String value) async {
    setState(() {}); // Updates live 0/10 counter
    final clean = value.trim();
    if (clean.length == 10) {
      try {
        final repo = ref.read(employeeRepositoryProvider);
        final empId = ref.read(currentEmployeeIdProvider);
        final isDup = await repo.isPhoneNumberDuplicate(
          employeeId: empId,
          phoneNumber: clean,
        );
        if (mounted) {
          setState(() {
            _duplicatePhoneWarning = isDup
                ? 'Warning: Phone number $clean is already registered for another shop in your assigned zones!'
                : null;
          });
        }
      } catch (_) {}
    } else {
      if (_duplicatePhoneWarning != null) {
        setState(() => _duplicatePhoneWarning = null);
      }
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (photo != null && mounted) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _capturedPhotoBytes = bytes;
          _photoUrlController.text = photo.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e'),
            backgroundColor: AddShopTheme.errorRed,
          ),
        );
      }
    }
  }

  void _onAgreedOpeningHourChanged(int newHour) {
    final allowed = _getAllowedPeriodsForHour(newHour, filterForToday: false);
    final newPeriod = allowed.any((p) => p['id'] == _agreedOpeningPeriod)
        ? _agreedOpeningPeriod!
        : allowed.first['id']!;
    _updateAgreedOpeningTime(newHour, newPeriod);
  }

  void _updateAgreedOpeningTime(int hour12, String period) {
    setState(() {
      _agreedOpeningHour12 = hour12;
      _agreedOpeningPeriod = period;
      const periodBengaliMap = {
        'sokal': 'সকাল',
        'dupur': 'দুপুর',
        'bikel': 'বিকাল',
        'sondhya': 'সন্ধ্যা',
        'rat': 'রাত',
      };
      final periodLabel = periodBengaliMap[period] ?? '';
      _openingTime = '$periodLabel $hour12';
    });
  }

  static const Map<int, String> _bengaliWeekdays = {
    DateTime.monday: 'সোম',
    DateTime.tuesday: 'মঙ্গল',
    DateTime.wednesday: 'বুধ',
    DateTime.thursday: 'বৃহস্পতি',
    DateTime.friday: 'শুক্র',
    DateTime.saturday: 'শনি',
    DateTime.sunday: 'রবি',
  };

  static const Map<int, String> _bengaliMonths = {
    1: 'জানু',
    2: 'ফেব্রু',
    3: 'মার্চ',
    4: 'এপ্রিল',
    5: 'মে',
    6: 'জুন',
    7: 'জুলাই',
    8: 'আগস্ট',
    9: 'সেপ্টে',
    10: 'অক্টো',
    11: 'নভে',
    12: 'ডিসে',
  };

  Future<void> _pickFollowupDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _followupDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_followupDateTime),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _followupDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      _syncPeriodAndHourFromDateTime();
    });
  }

  DateTime? get _effectiveFollowupDateTime {
    if (_selectedFollowupDate == null || _selectedHour12 == null || _selectedPeriod == null) {
      return null;
    }
    final h24 = _calculate24Hour(_selectedHour12!, _selectedPeriod!);
    return DateTime(
      _selectedFollowupDate!.year,
      _selectedFollowupDate!.month,
      _selectedFollowupDate!.day,
      h24,
      0,
    );
  }

  bool get _isTodaySelected {
    if (_selectedFollowupDate == null) return false;
    final now = DateTime.now();
    return _selectedFollowupDate!.year == now.year &&
        _selectedFollowupDate!.month == now.month &&
        _selectedFollowupDate!.day == now.day;
  }

  bool _isSlotInPastForToday(int hour12, String period) {
    if (!_isTodaySelected) return false;
    final now = DateTime.now();
    final h24 = _calculate24Hour(hour12, period);
    final slot = DateTime(now.year, now.month, now.day, h24, 0);
    return !slot.isAfter(now);
  }

  Future<void> _pickCustomFollowupDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedFollowupDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (pickedDate != null && mounted) {
      _applyFollowupDate(pickedDate);
    }
  }

  Future<void> _pickFollowupTimeOnly() async {
    final initial = _effectiveFollowupDateTime ?? DateTime.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime != null && mounted) {
      setState(() {
        _followupDateTime = DateTime(
          _selectedFollowupDate?.year ?? initial.year,
          _selectedFollowupDate?.month ?? initial.month,
          _selectedFollowupDate?.day ?? initial.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        _syncPeriodAndHourFromDateTime();
      });
    }
  }

  List<Map<String, String>> _getBasePeriodsForHour(int? hour12) {
    if (hour12 == null) {
      return const [];
    }
    if (hour12 == 11 || hour12 == 12) {
      // 11 and 12: automatically sokal only
      return const [
        {'id': 'sokal', 'label': 'সকাল'},
      ];
    } else if (hour12 >= 1 && hour12 <= 3) {
      // 1 to 3: automatically dupur only
      return const [
        {'id': 'dupur', 'label': 'দুপুর'},
      ];
    } else if (hour12 >= 4 && hour12 <= 5) {
      // 4 to 5: automatically bikel only
      return const [
        {'id': 'bikel', 'label': 'বিকাল'},
      ];
    } else if (hour12 == 6) {
      // 6: automatically sondhya only
      return const [
        {'id': 'sondhya', 'label': 'সন্ধ্যা'},
      ];
    } else if (hour12 >= 7 && hour12 <= 10) {
      // 7 to 10: two options to select: sokal and rat
      return const [
        {'id': 'sokal', 'label': 'সকাল'},
        {'id': 'rat', 'label': 'রাত'},
      ];
    }
    return const [
      {'id': 'sokal', 'label': 'সকাল'},
    ];
  }

  List<Map<String, String>> _getAllowedPeriodsForHour(int? hour12, {bool filterForToday = true}) {
    final base = _getBasePeriodsForHour(hour12);
    if (filterForToday && _isTodaySelected && hour12 != null) {
      return base.where((p) => !_isSlotInPastForToday(hour12, p['id']!)).toList();
    }
    return base;
  }

  int _calculate24Hour(int hour12, String period) {
    if (hour12 == 11) {
      return 11; // 11 AM
    } else if (hour12 == 12) {
      return 12; // 12 PM (noon)
    } else if (hour12 >= 1 && hour12 <= 3) {
      return hour12 + 12; // 1 PM, 2 PM, 3 PM (13, 14, 15)
    } else if (hour12 >= 4 && hour12 <= 5) {
      return hour12 + 12; // 4 PM, 5 PM (16, 17) - bikel
    } else if (hour12 == 6) {
      return 18; // 6 PM (18) - sondhya
    } else if (hour12 >= 7 && hour12 <= 10) {
      if (period == 'sokal') {
        return hour12; // 7 AM, 8 AM, 9 AM, 10 AM (7, 8, 9, 10)
      } else {
        return hour12 + 12; // 7 PM, 8 PM, 9 PM, 10 PM (19, 20, 21, 22)
      }
    }
    return hour12;
  }

  void _applyFollowupDate(DateTime pickedDate) {
    final now = DateTime.now();
    final isToday = pickedDate.year == now.year &&
        pickedDate.month == now.month &&
        pickedDate.day == now.day;

    setState(() {
      _selectedFollowupDate = pickedDate;

      if (isToday) {
        if (_selectedHour12 != null) {
          final allowed = _getAllowedPeriodsForHour(_selectedHour12, filterForToday: true);
          if (allowed.isEmpty) {
            final prevHour = _selectedHour12;
            _selectedHour12 = null;
            _selectedPeriod = null;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('আজকের $prevHour-টার সময় ইতিমধ্যেই পার হয়ে গেছে। অনুগ্রহ করে বর্তমান সময়ের পরের সময় বাছুন।'),
                backgroundColor: AddShopTheme.accentOrangeDark,
                duration: const Duration(seconds: 3),
              ),
            );
          } else if (_selectedPeriod != null && !allowed.any((p) => p['id'] == _selectedPeriod)) {
            final prevPeriodLabel = _selectedPeriod == 'sokal' ? 'সকাল' : _selectedPeriod!;
            _selectedPeriod = allowed.first['id'];
            final newPeriodLabel = allowed.first['label'];
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('আজকের $prevPeriodLabel $_selectedHour12 পার হওয়ায় স্বয়ংক্রিয়ভাবে $newPeriodLabel $_selectedHour12 নির্বাচন করা হয়েছে।'),
                backgroundColor: AddShopTheme.accentOrangeDark,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }

      if (_selectedHour12 != null && _selectedPeriod != null) {
        final new24Hour = _calculate24Hour(_selectedHour12!, _selectedPeriod!);
        _followupDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          new24Hour,
          0,
        );
      }
    });
  }

  void _onHourChanged(int newHour) {
    final allowed = _getAllowedPeriodsForHour(newHour, filterForToday: true);
    if (allowed.isEmpty) return;
    final newPeriod = allowed.any((p) => p['id'] == _selectedPeriod)
        ? _selectedPeriod!
        : allowed.first['id']!;
    _updateFollowupTime(newHour, newPeriod);
  }

  void _updateFollowupTime(int hour12, String period) {
    setState(() {
      _selectedHour12 = hour12;
      _selectedPeriod = period;
      if (_selectedFollowupDate != null) {
        final new24Hour = _calculate24Hour(hour12, period);
        _followupDateTime = DateTime(
          _selectedFollowupDate!.year,
          _selectedFollowupDate!.month,
          _selectedFollowupDate!.day,
          new24Hour,
          0,
        );
      }
    });
  }

  void _syncPeriodAndHourFromDateTime() {
    final h = _followupDateTime.hour;
    final hour12 = (h % 12 == 0) ? 12 : h % 12;
    _selectedHour12 = hour12;
    final allowed = _getAllowedPeriodsForHour(hour12, filterForToday: true);
    if (hour12 >= 7 && hour12 <= 10) {
      if (h >= 19 && h <= 22) {
        _selectedPeriod = 'rat';
      } else {
        _selectedPeriod = 'sokal';
      }
    } else {
      _selectedPeriod = allowed.isNotEmpty ? allowed.first['id'] : 'sokal';
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final period = time.period == DayPeriod.pm ? 'PM' : 'AM';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final min = time.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  void _saveOfflineDraft() async {
    final effectiveShopName = _isAgreed
        ? _shopNameController.text.trim()
        : (_shopNameController.text.trim().isNotEmpty
            ? _shopNameController.text.trim()
            : '${_selectedCategory} Lead');

    final effectiveOwnerName = _isAgreed
        ? _ownerNameController.text.trim()
        : (_ownerNameController.text.trim().isNotEmpty
            ? _ownerNameController.text.trim()
            : 'Prospective Owner');

    final draft = {
      'id': 'draft-${DateTime.now().millisecondsSinceEpoch}',
      'zone_id': widget.zoneId ?? '',
      'zone_name': widget.zoneName ?? 'Assigned Zone',
      'owner_name': effectiveOwnerName,
      'phone_number': _phoneNumberController.text.trim(),
      'shop_name': effectiveShopName,
      'category': _selectedCategory,
      'latitude': widget.latitude ?? 22.5726,
      'longitude': widget.longitude ?? 88.3639,
      'opening_time': _isAgreed ? _openingTime : '09:00 AM',
      'closing_time': '09:00 PM',
      'weekly_closed_day': _isAgreed ? _weeklyClosedDay : 'None',
      'landmark': null,
      'is_agreed': _isAgreed,
      'followup_reason': _followupReasonController.text.trim(),
      'next_followup_date': _effectiveFollowupDateTime?.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final repo = ref.read(employeeRepositoryProvider);
      await repo.saveOfflineDraft(draft);
      ref.invalidate(offlineDraftsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shop details saved as offline draft successfully!'),
          backgroundColor: AddShopTheme.primaryTealDark,
        ),
      );
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save draft: $e'),
          backgroundColor: AddShopTheme.errorRed,
        ),
      );
    }
  }

  void _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isAgreed && _followupReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Follow-up reason is strictly mandatory for follow-up shops!'),
          backgroundColor: AddShopTheme.errorRed,
        ),
      );
      return;
    }

    if (!_isAgreed && _selectedFollowupDate == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a revisit date (তারিখ নির্বাচন করুন)!'),
          backgroundColor: AddShopTheme.errorRed,
        ),
      );
      return;
    }

    if (!_isAgreed && (_selectedHour12 == null || _selectedPeriod == null)) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a revisit time (সময় নির্বাচন করুন)!'),
          backgroundColor: AddShopTheme.errorRed,
        ),
      );
      return;
    }

    final scheduledDateTime = _effectiveFollowupDateTime;
    if (!_isAgreed && (scheduledDateTime == null || !scheduledDateTime.isAfter(DateTime.now()))) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisit time cannot be in the past (অতীতের সময় বাছা যাবে না)!'),
          backgroundColor: AddShopTheme.errorRed,
        ),
      );
      return;
    }

    if (_isAgreed && _agreedOpeningHour12 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an opening time (দোকান খোলার সময় নির্বাচন করুন)!'),
          backgroundColor: AddShopTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(employeeRepositoryProvider);
      final empId = ref.read(currentEmployeeIdProvider);

      final effectiveShopName = _isAgreed
          ? _shopNameController.text.trim()
          : (_shopNameController.text.trim().isNotEmpty
              ? _shopNameController.text.trim()
              : '${_selectedCategory} Lead');

      final effectiveOwnerName = _isAgreed
          ? _ownerNameController.text.trim()
          : (_ownerNameController.text.trim().isNotEmpty
              ? _ownerNameController.text.trim()
              : 'Prospective Owner');

      final effectivePhoneNumber = _phoneNumberController.text.trim().isNotEmpty
          ? _phoneNumberController.text.trim()
          : 'N/A';

      final newShop = await repo.addShop(
        employeeId: empId,
        ownerName: effectiveOwnerName,
        phoneNumber: effectivePhoneNumber,
        shopName: effectiveShopName,
        category: _selectedCategory,
        latitude: widget.latitude ?? 22.5726,
        longitude: widget.longitude ?? 88.3639,
        openingTime: _isAgreed ? _openingTime : '09:00 AM',
        closingTime: '09:00 PM',
        weeklyClosedDay: _isAgreed ? _weeklyClosedDay : 'None',
        shopfrontPhotoUrl: _isAgreed && _photoUrlController.text.trim().isNotEmpty
            ? _photoUrlController.text.trim()
            : null,
        landmark: null,
        isAgreed: _isAgreed,
        followupReason: !_isAgreed ? _followupReasonController.text.trim() : null,
        nextFollowupDate: !_isAgreed ? scheduledDateTime : null,
      );

      ref.invalidate(assignedShopsProvider);
      ref.invalidate(followupsTodayProvider);
      ref.invalidate(overdueFollowupsProvider);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (_isAgreed) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AddShopTheme.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AddShopTheme.radiusCard),
            ),
            icon: const Icon(
              Icons.verified_rounded,
              color: AddShopTheme.primaryTeal,
              size: 54,
            ),
            title: const Text(
              'Shop Successfully Registered!',
              style: TextStyle(
                color: AddShopTheme.textDarkSlate,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Shop "${newShop.shopName}" has been successfully added to '
                  '${widget.zoneName ?? "your assigned zone"} as an Agreed & Active shop.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AddShopTheme.textBody,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'IMMUTABLE 8-DIGIT SHOP CODE:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AddShopTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AddShopTheme.primaryTealLight,
                    borderRadius: BorderRadius.circular(AddShopTheme.radiusInput),
                    border: Border.all(color: AddShopTheme.primaryTeal, width: 2),
                  ),
                  child: SelectableText(
                    newShop.shopCode ?? '10000001',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: AddShopTheme.primaryTeal,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This 8-digit code is permanently assigned by the system.',
                  style: TextStyle(fontSize: 11, color: AddShopTheme.textMuted),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AddShopTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AddShopTheme.radiusButton),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Return to Map',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newShop.isFollowupToday
                  ? 'Follow-up scheduled for today for "${newShop.shopName}"! Marked in Orange on map.'
                  : 'Follow-up scheduled for "${newShop.shopName}"! Marked in Blue on map.',
            ),
            backgroundColor: AddShopTheme.accentOrange,
          ),
        );
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add shop: $e'),
            backgroundColor: AddShopTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AddShopTheme.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AddShopTheme.textDarkSlate,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Add Shop to Assigned Zone',
          style: TextStyle(
            color: AddShopTheme.textDarkSlate,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AddShopTheme.cardBorder, height: 1),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: InkWell(
                onTap: _saveOfflineDraft,
                borderRadius: BorderRadius.circular(AddShopTheme.radiusPill),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AddShopTheme.primaryTealLight,
                    borderRadius: BorderRadius.circular(AddShopTheme.radiusPill),
                    border: Border.all(
                      color: AddShopTheme.primaryTeal.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.save_outlined,
                        size: 15,
                        color: AddShopTheme.primaryTeal,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Save Draft',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AddShopTheme.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Zone & Geo coordinates Gradient Banner
                  _buildZoneBanner(),

                  const SizedBox(height: 16),

                  // Nearby duplicate warning (<20m)
                  if (_nearbyDuplicateShops.isNotEmpty) ...[
                    _buildNearbyDuplicateWarning(),
                    const SizedBox(height: 16),
                  ],

                  // Duplicate phone warning
                  if (_duplicatePhoneWarning != null) ...[
                    _buildDuplicatePhoneWarning(),
                    const SizedBox(height: 16),
                  ],

                  // 2. Shop Agreement Status Segmented Toggle
                  _buildAgreementStatusToggle(),

                  const SizedBox(height: 16),

                  // 3. Conditional Form Fields based on Agreement Status
                  if (_isAgreed) ...[
                    // AGREED & ACTIVE MODE: Show All Operational Fields
                    _buildBasicInfoCard(),
                    const SizedBox(height: 16),
                    _buildScheduleCard(),
                    const SizedBox(height: 16),
                    _buildPhotoCaptureCard(),
                  ] else ...[
                    // NEEDS FOLLOW-UP MODE: Lean, Quick-Capture Form
                    // Kept fields: Category, Reason, Phone (Optional), Schedule date & time
                    _buildFollowupCard(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildStickyBottomBar(),
    );
  }

  /// 1. Zone Gradient Banner
  Widget _buildZoneBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AddShopTheme.primaryTeal,
            Color(0xFF26B69E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AddShopTheme.radiusCard),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 157, 138, 0.22),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.zoneName ?? 'Kolkata Central Zone',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Coords: ${widget.latitude?.toStringAsFixed(4) ?? "22.5726"}, '
                  '${widget.longitude?.toStringAsFixed(4) ?? "88.3639"} (Validated Inside Boundary)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(AddShopTheme.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ShopCategory.fromString(_selectedCategory).icon,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${ShopCategory.fromString(_selectedCategory).displayName} (${ShopCategory.fromString(_selectedCategory).bengaliName})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AddShopTheme.radiusPill),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: AddShopTheme.primaryTeal,
                ),
                SizedBox(width: 4),
                Text(
                  'Zone Verified',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AddShopTheme.primaryTealDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Warning: Nearby duplicate shops
  Widget _buildNearbyDuplicateWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AddShopTheme.warningAmberLight,
        borderRadius: BorderRadius.circular(AddShopTheme.radiusInput),
        border: Border.all(color: AddShopTheme.warningAmber.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AddShopTheme.warningAmber,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nearby Duplicate Warning (<20m):',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Found ${_nearbyDuplicateShops.length} existing shop(s) within 20m of this pin: '
                  '${_nearbyDuplicateShops.map((s) => s.shopName).join(", ")}. '
                  'Please confirm this is not a duplicate shop.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Warning: Duplicate phone
  Widget _buildDuplicatePhoneWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AddShopTheme.errorRedLight,
        borderRadius: BorderRadius.circular(AddShopTheme.radiusInput),
        border: Border.all(color: AddShopTheme.errorRed.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AddShopTheme.errorRed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _duplicatePhoneWarning!,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Segmented Toggle: Agreed vs Needs Follow-up
  Widget _buildAgreementStatusToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AddShopTheme.cardBackground,
        borderRadius: BorderRadius.circular(AddShopTheme.radiusCard),
        border: Border.all(color: AddShopTheme.cardBorder),
        boxShadow: AddShopTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.handshake_outlined, size: 18, color: AddShopTheme.primaryTeal),
              SizedBox(width: 8),
              Text(
                'Shop Agreement Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AddShopTheme.textDarkSlate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Option 1: Agreed & Active
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isAgreed = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _isAgreed
                          ? AddShopTheme.primaryTeal
                          : AddShopTheme.cardBackground,
                      borderRadius: BorderRadius.circular(AddShopTheme.radiusInput),
                      border: Border.all(
                        color: _isAgreed
                            ? AddShopTheme.primaryTeal
                            : AddShopTheme.cardBorder,
                        width: _isAgreed ? 2 : 1,
                      ),
                      boxShadow: _isAgreed
                          ? [
                              BoxShadow(
                                color: AddShopTheme.primaryTeal.withValues(alpha: 0.28),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isAgreed
                              ? Icons.check_circle_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 18,
                          color: _isAgreed ? Colors.white : AddShopTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Agreed & Active',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _isAgreed ? Colors.white : AddShopTheme.textBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Option 2: Needs Follow-up
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isAgreed = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_isAgreed
                          ? AddShopTheme.accentOrange
                          : AddShopTheme.cardBackground,
                      borderRadius: BorderRadius.circular(AddShopTheme.radiusInput),
                      border: Border.all(
                        color: !_isAgreed
                            ? AddShopTheme.accentOrange
                            : AddShopTheme.cardBorder,
                        width: !_isAgreed ? 2 : 1,
                      ),
                      boxShadow: !_isAgreed
                          ? [
                              BoxShadow(
                                color: AddShopTheme.accentOrange.withValues(alpha: 0.28),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          !_isAgreed
                              ? Icons.schedule_rounded
                              : Icons.schedule_outlined,
                          size: 18,
                          color: !_isAgreed ? Colors.white : AddShopTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Needs Follow-up',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: !_isAgreed ? Colors.white : AddShopTheme.textBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 3. Basic Information Card (Used in Agreed Mode)
  Widget _buildBasicInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AddShopTheme.cardBackground,
        borderRadius: BorderRadius.circular(AddShopTheme.radiusCard),
        border: Border.all(color: AddShopTheme.cardBorder),
        boxShadow: AddShopTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.storefront_rounded,
            title: 'Basic Information',
          ),
          const SizedBox(height: 16),

          // Shop Name
          TextFormField(
            controller: _shopNameController,
            style: const TextStyle(
              fontSize: 14,
              color: AddShopTheme.textDarkSlate,
              fontWeight: FontWeight.w500,
            ),
            decoration: _inputDecoration(
              label: 'Shop Name *',
              hint: 'e.g. Ghosh Sweets & Snacks',
              prefixIcon: Icons.store_rounded,
            ),
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Shop name is required' : null,
          ),
          const SizedBox(height: 14),

          // Owner Name
          TextFormField(
            controller: _ownerNameController,
            style: const TextStyle(
              fontSize: 14,
              color: AddShopTheme.textDarkSlate,
              fontWeight: FontWeight.w500,
            ),
            decoration: _inputDecoration(
              label: 'Owner Name *',
              hint: 'e.g. Subir Ghosh',
              prefixIcon: Icons.person_rounded,
            ),
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Owner name is required' : null,
          ),
          const SizedBox(height: 14),

          // Phone Number with live 0/10 counter
          TextFormField(
            controller: _phoneNumberController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            style: const TextStyle(
              fontSize: 14,
              color: AddShopTheme.textDarkSlate,
              fontWeight: FontWeight.w500,
            ),
            decoration: _inputDecoration(
              label: 'Phone Number (10 Digits) *',
              hint: '9876543210',
              prefixIcon: Icons.phone_rounded,
              suffixWidget: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_phoneNumberController.text.length}/10',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _phoneNumberController.text.length == 10
                            ? AddShopTheme.successGreen
                            : AddShopTheme.textMuted,
                      ),
                    ),
                    if (_phoneNumberController.text.length == 10) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: AddShopTheme.successGreen,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Phone number is required';
              if (val.trim().length != 10) return 'Must be exactly 10 digits';
              return null;
            },
            onChanged: _onPhoneChanged,
          ),
        ],
      ),
    );
  }

  /// 4. Operating Hours & Schedule Card (Used in Agreed Mode)
  /// Opening time only (clock selection matching follow-up), no closing time, weekly closed as Bengali bars
  Widget _buildScheduleCard() {
    final allowedPeriods = _getAllowedPeriodsForHour(_agreedOpeningHour12, filterForToday: false);

    const periodBengaliMap = {
      'sokal': 'সকাল',
      'dupur': 'দুপুর',
      'bikel': 'বিকাল',
      'sondhya': 'সন্ধ্যা',
      'rat': 'রাত',
    };
    final periodName = _agreedOpeningPeriod != null ? (periodBengaliMap[_agreedOpeningPeriod] ?? '') : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AddShopTheme.cardBackground,
        borderRadius: BorderRadius.circular(AddShopTheme.radiusCard),
        border: Border.all(color: AddShopTheme.cardBorder),
        boxShadow: AddShopTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.schedule_rounded,
            title: 'Operating Hours & Schedule',
          ),
          const SizedBox(height: 16),

          // Opening Time Header & Pill
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 15,
                color: AddShopTheme.primaryTealDark,
              ),
              const SizedBox(width: 6),
              const Text(
                'Opening Time (দোকান খোলার সময়)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AddShopTheme.textDarkSlate,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AddShopTheme.primaryTealLight,
                  borderRadius: BorderRadius.circular(AddShopTheme.radiusPill),
                  border: Border.all(
                    color: AddShopTheme.primaryTeal.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: AddShopTheme.primaryTealDark,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _agreedOpeningHour12 != null
                          ? '$periodName $_agreedOpeningHour12'
                          : 'সময় বাছুন',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AddShopTheme.primaryTealDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Dropdown 1 to 12 + contextual period buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 1 to 12 Dropdown
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AddShopTheme.radiusInput),
                    border: Border.all(
                      color: AddShopTheme.primaryTeal.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(16, 24, 40, 0.04),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _agreedOpeningHour12,
                      hint: const Text(
                        'সময়',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AddShopTheme.textMuted,
                        ),
                      ),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 6,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AddShopTheme.primaryTealDark,
                        size: 20,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AddShopTheme.textDarkSlate,
                      ),
                      items: List.generate(12, (index) {
                        final hour = index + 1;
                        return DropdownMenuItem<int>(
                          value: hour,
                          child: Text(
                            '$hour',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AddShopTheme.textDarkSlate,
                            ),
                          ),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) {
                          _onAgreedOpeningHourChanged(val);
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Period Buttons
                if (allowedPeriods.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      'সময় বাছুন',
                      style: TextStyle(
                        fontSize: 12,
                        color: AddShopTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  ...allowedPeriods.map((btn) {
                    final id = btn['id'] as String;
                    final label = btn['label'] as String;
                    final isSelected = _agreedOpeningPeriod == id;

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected && _agreedOpeningHour12 != null) {
                            _updateAgreedOpeningTime(_agreedOpeningHour12!, id);
                          }
                        },
                        selectedColor: AddShopTheme.primaryTeal,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AddShopTheme.textBody,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AddShopTheme.primaryTeal
                              : AddShopTheme.cardBorder,
                          width: isSelected ? 1.5 : 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AddShopTheme.radiusPill),
                        ),
                        showCheckmark: false,
                      ),
                    );
                  }),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Weekly Closed Day (Bengali Written Bars, No Date Required)
          const Row(
            children: [
              Icon(
                Icons.event_busy_rounded,
                size: 15,
                color: AddShopTheme.primaryTealDark,
              ),
              SizedBox(width: 6),
              Text(
                'Weekly Closed Day (সাপ্তাহিক বন্ধের বার)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AddShopTheme.textDarkSlate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _bengaliWeeklyClosedOptions.map((opt) {
                final id = opt['id']!;
                final label = opt['label']!;
                final isSelected = _weeklyClosedDay == id;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _weeklyClosedDay = id);
                      }
                    },
                    selectedColor: AddShopTheme.primaryTeal,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : AddShopTheme.textBody,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AddShopTheme.primaryTeal
                          : AddShopTheme.cardBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AddShopTheme.radiusPill),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Shopfront Photo Capture Card (Used in Agreed Mode)
  /// Camera capture box only (No photo URL field, no landmark field)
  Widget _buildPhotoCaptureCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AddShopTheme.cardBackground,
        borderRadius: BorderRadius.circular(AddShopTheme.radiusCard),
        border: Border.all(color: AddShopTheme.cardBorder),
        boxShadow: AddShopTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionHeader(
                icon: Icons.camera_alt_outlined,
                title: 'Shopfront Photo',
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AddShopTheme.pageBackground,
                  borderRadius: BorderRadius.circular(AddShopTheme.radiusPill),
                  border: Border.all(color: AddShopTheme.cardBorder),
                ),
                child: const Text(
                  'Optional',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AddShopTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Dedicated Camera Capture Box
          InkWell(
            onTap: _capturePhoto,
            borderRadius: BorderRadius.circular(AddShopTheme.radiusInput),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AddShopTheme.pageBackground,
                borderRadius: BorderRadius.circular(AddShopTheme.radiusInput),
                border: Border.all(
                  color: AddShopTheme.primaryTeal.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: _capturedPhotoBytes != null
                  ? Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _capturedPhotoBytes!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Photo Captured Successfully',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AddShopTheme.textDarkSlate,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Tap to retake / change photo',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AddShopTheme.primaryTealDark,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AddShopTheme.errorRed),
                          onPressed: () {
                            setState(() {
                              _capturedPhotoBytes = null;
                              _photoUrlController.clear();
                            });
                          },
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: AddShopTheme.primaryTealLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 28,
                            color: AddShopTheme.primaryTeal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Capture Shopfront Photo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AddShopTheme.primaryTealDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Tap to open camera & take shop photo',
                          style: TextStyle(
                            fontSize: 11,
                            color: AddShopTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// 6. Follow-up Mandatory Section Card (Used in Needs Follow-up Mode)
  /// Contains: Category, Reason for Follow-up *, Schedule Revisit Date & Time
  Widget _buildFollowupCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AddShopTheme.cardBackground,
        borderRadius: BorderRadius.circular(AddShopTheme.radiusCard),
        border: Border.all(color: AddShopTheme.accentOrange.withValues(alpha: 0.4)),
        boxShadow: AddShopTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AddShopTheme.accentOrangeLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  color: AddShopTheme.accentOrange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Follow-up Parameters (Mandatory)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AddShopTheme.accentOrangeDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Reason for Follow-up *
          TextFormField(
            controller: _followupReasonController,
            style: const TextStyle(
              fontSize: 14,
              color: AddShopTheme.textDarkSlate,
            ),
            decoration: _inputDecoration(
              label: 'Reason for Follow-up *',
              hint: 'e.g. Owner requested visit after 5 PM / Decision maker out',
              prefixIcon: Icons.comment_outlined,
              accentColor: AddShopTheme.accentOrange,
            ),
            validator: (val) => val == null || val.trim().isEmpty
                ? 'Follow-up reason is required'
                : null,
          ),

          const SizedBox(height: 14),

          // Optional Field: Phone Number (with live 0/10 counter)
          TextFormField(
            controller: _phoneNumberController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            style: const TextStyle(
              fontSize: 14,
              color: AddShopTheme.textDarkSlate,
              fontWeight: FontWeight.w500,
            ),
            decoration: _inputDecoration(
              label: 'Phone Number (Optional)',
              hint: '9876543210',
              prefixIcon: Icons.phone_rounded,
              accentColor: AddShopTheme.accentOrange,
              suffixWidget: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_phoneNumberController.text.length}/10',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _phoneNumberController.text.length == 10
                            ? AddShopTheme.successGreen
                            : AddShopTheme.textMuted,
                      ),
                    ),
                    if (_phoneNumberController.text.length == 10) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: AddShopTheme.successGreen,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            validator: (val) {
              if (val != null && val.trim().isNotEmpty && val.trim().length != 10) {
                return 'Must be exactly 10 digits if provided';
              }
              return null;
            },
            onChanged: _onPhoneChanged,
          ),

          const SizedBox(height: 18),

          // Kept Field 3: 20-Day Bengali Revisit Date Selector (5 visible on mobile)
          _buildBengaliRevisitDatePicker(),

          const SizedBox(height: 16),

          // Kept Field 4: Revisit Time Selector
          _buildFollowupTimeSelector(),

          const SizedBox(height: 14),

          // Kept Field 5: Revisit Confirmation Banner
          _buildFollowupSummaryBanner(),
        ],
      ),
    );
  }

  /// 20-Day Bengali Revisit Date Selector (5 days visible on mobile screen)
  Widget _buildBengaliRevisitDatePicker() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = _selectedFollowupDate != null
        ? DateTime(
            _selectedFollowupDate!.year,
            _selectedFollowupDate!.month,
            _selectedFollowupDate!.day,
          )
        : null;

    // 20 consecutive days starting from today (Day 0 to Day 19)
    final days = List.generate(20, (i) => today.add(Duration(days: i)));

    // Check if the selected date is one of the 20 days
    final isCustomDateSelected = selectedDay != null &&
        !days.any((d) =>
            d.year == selectedDay.year &&
            d.month == selectedDay.month &&
            d.day == selectedDay.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 15,
              color: AddShopTheme.accentOrangeDark,
            ),
            const SizedBox(width: 6),
            const Text(
              'Select Revisit Date',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AddShopTheme.textDarkSlate,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AddShopTheme.accentOrangeLight,
                borderRadius: BorderRadius.circular(AddShopTheme.radiusPill),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '20 Days',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AddShopTheme.accentOrangeDark,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 11,
                    color: AddShopTheme.accentOrangeDark,
                  ),
                ],
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: _pickCustomFollowupDate,
              borderRadius: BorderRadius.circular(AddShopTheme.radiusPill),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCustomDateSelected
                      ? AddShopTheme.accentOrange
                      : AddShopTheme.accentOrangeLight,
                  borderRadius: BorderRadius.circular(AddShopTheme.radiusPill),
                  border: Border.all(
                    color: AddShopTheme.accentOrange.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_calendar_rounded,
                      size: 13,
                      color: isCustomDateSelected
                          ? Colors.white
                          : AddShopTheme.accentOrangeDark,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCustomDateSelected ? 'Other Date' : 'Calendar',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isCustomDateSelected
                            ? Colors.white
                            : AddShopTheme.accentOrangeDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.maxScrollExtent > 0) {
              final canScroll = notification.metrics.pixels <
                  notification.metrics.maxScrollExtent - 8;
              if (canScroll != _showRightDateArrow) {
                setState(() => _showRightDateArrow = canScroll);
              }
            }
            return false;
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              const double spacing = 8.0;
              // Exactly 5 items visible across the mobile card width (<= 480px)
              final double itemWidth = (constraints.maxWidth <= 480)
                  ? ((constraints.maxWidth - (spacing * 4)) / 5).clamp(48.0, 72.0)
                  : 60.0;

              return SizedBox(
                height: 76,
                child: Stack(
                  children: [
                    ListView.separated(
                      controller: _dateScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 28),
                      itemCount: 20,
                      separatorBuilder: (_, __) => const SizedBox(width: spacing),
                      itemBuilder: (context, index) {
                        final dayDate = days[index];
                        final isSelected = selectedDay != null &&
                            selectedDay.year == dayDate.year &&
                            selectedDay.month == dayDate.month &&
                            selectedDay.day == dayDate.day;
                        final isToday = index == 0;
                        // Today shows 'আজকে', subsequent days show Bengali weekday name (মঙ্গল, বুধ, etc.)
                        final topLabel = isToday
                            ? 'আজকে'
                            : (_bengaliWeekdays[dayDate.weekday] ?? '');

                        return InkWell(
                          onTap: () => _applyFollowupDate(dayDate),
                          borderRadius: BorderRadius.circular(AddShopTheme.radiusInput),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            width: itemWidth,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AddShopTheme.accentOrange
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(AddShopTheme.radiusInput),
                              border: Border.all(
                                color: isSelected
                                    ? AddShopTheme.accentOrange
                                    : AddShopTheme.cardBorder,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AddShopTheme.accentOrange.withValues(alpha: 0.32),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : [
                                      const BoxShadow(
                                        color: Color.fromRGBO(16, 24, 40, 0.04),
                                        blurRadius: 4,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Top: 'আজকে' or Bengali weekday
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    topLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : (isToday
                                              ? AddShopTheme.accentOrangeDark
                                              : AddShopTheme.textDarkSlate),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Under that: date number
                                Text(
                                  '${dayDate.day}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : AddShopTheme.textDarkSlate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // Right-side arrow indicator showing more dates to view by scrolling
                    if (_showRightDateArrow)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              if (_dateScrollController.hasClients) {
                                _dateScrollController.animateTo(
                                  (_dateScrollController.offset + (itemWidth * 3 + spacing * 3)).clamp(
                                    0.0,
                                    _dateScrollController.position.maxScrollExtent,
                                  ),
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                );
                              }
                            },
                            child: Container(
                              width: 24,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                                border: Border.all(
                                  color: AddShopTheme.accentOrange.withValues(alpha: 0.5),
                                  width: 1.2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(0, 0, 0, 0.12),
                                    blurRadius: 6,
                                    offset: Offset(-2, 1),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 13,
                                  color: AddShopTheme.accentOrange,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Revisit Time Selector with 1 to 12 dropdown and contextual period buttons
  Widget _buildFollowupTimeSelector() {
    if (_selectedHour12 != null) {
      final allowedForSelected = _getAllowedPeriodsForHour(_selectedHour12, filterForToday: true);
      if (_isTodaySelected && allowedForSelected.isEmpty) {
        _selectedHour12 = null;
        _selectedPeriod = null;
      }
    }

    final allowedPeriods = _getAllowedPeriodsForHour(_selectedHour12, filterForToday: true);

    const periodBengaliMap = {
      'sokal': 'সকাল',
      'dupur': 'দুপুর',
      'bikel': 'বিকাল',
      'sondhya': 'সন্ধ্যা',
      'rat': 'রাত',
    };
    final periodName = _selectedPeriod != null ? (periodBengaliMap[_selectedPeriod] ?? '') : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.access_time_rounded,
              size: 15,
              color: AddShopTheme.accentOrangeDark,
            ),
            const SizedBox(width: 6),
            const Text(
              'Select Revisit Time',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AddShopTheme.textDarkSlate,
              ),
            ),
            const Spacer(),
            // Current formatted time display pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AddShopTheme.accentOrangeLight,
                borderRadius: BorderRadius.circular(AddShopTheme.radiusPill),
                border: Border.all(
                  color: AddShopTheme.accentOrange.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 12,
                    color: AddShopTheme.accentOrangeDark,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _selectedHour12 != null
                        ? '$periodName $_selectedHour12'
                        : 'সময় বাছুন',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AddShopTheme.accentOrangeDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Dropdown of 1 to 12 and after that buttons: contextual per rules
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // 1. Dropdown of 1 to 12
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AddShopTheme.radiusInput),
                  border: Border.all(
                    color: AddShopTheme.accentOrange.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(16, 24, 40, 0.04),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedHour12,
                    hint: const Text(
                      'সময়',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AddShopTheme.textMuted,
                      ),
                    ),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 6,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AddShopTheme.accentOrangeDark,
                      size: 20,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AddShopTheme.textDarkSlate,
                    ),
                    items: List.generate(12, (index) {
                      final hour = index + 1; // 1 to 12
                      final allowed = _getAllowedPeriodsForHour(hour, filterForToday: true);
                      final isAvailable = !_isTodaySelected || allowed.isNotEmpty;

                      return DropdownMenuItem<int>(
                        value: hour,
                        enabled: isAvailable,
                        child: Text(
                          isAvailable ? '$hour' : '$hour (সময় পার)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isAvailable
                                ? AddShopTheme.textDarkSlate
                                : AddShopTheme.textMuted.withValues(alpha: 0.45),
                            decoration: isAvailable ? null : TextDecoration.lineThrough,
                          ),
                        ),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) {
                        _onHourChanged(val);
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // 2. Period Buttons: dynamically showing only allowed options per hour rules
              if (allowedPeriods.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    'সময় বাছুন',
                    style: TextStyle(
                      fontSize: 12,
                      color: AddShopTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                ...allowedPeriods.map((btn) {
                  final id = btn['id'] as String;
                  final label = btn['label'] as String;
                  final isSelected = _selectedPeriod == id;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected && _selectedHour12 != null) {
                          if (_isSlotInPastForToday(_selectedHour12!, id)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('অতীতের সময় বাছা যাবে না!'),
                                backgroundColor: AddShopTheme.errorRed,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          _updateFollowupTime(_selectedHour12!, id);
                        }
                      },
                      selectedColor: AddShopTheme.accentOrange,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : AddShopTheme.textBody,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? AddShopTheme.accentOrange
                            : AddShopTheme.cardBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AddShopTheme.radiusPill),
                      ),
                      showCheckmark: false,
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  /// Revisit Confirmation Banner
  Widget _buildFollowupSummaryBanner() {
    final now = DateTime.now();
    final hasDate = _selectedFollowupDate != null;
    final isToday = hasDate &&
        _selectedFollowupDate!.year == now.year &&
        _selectedFollowupDate!.month == now.month &&
        _selectedFollowupDate!.day == now.day;
    final dayLabel = !hasDate
        ? ''
        : isToday
            ? 'আজকে'
            : (_bengaliWeekdays[_selectedFollowupDate!.weekday] ?? '');
    final month = hasDate ? (_bengaliMonths[_selectedFollowupDate!.month] ?? '') : '';

    const periodBengaliMap = {
      'sokal': 'সকাল',
      'dupur': 'দুপুর',
      'bikel': 'বিকাল',
      'sondhya': 'সন্ধ্যা',
      'rat': 'রাত',
    };
    final periodName = _selectedPeriod != null ? (periodBengaliMap[_selectedPeriod] ?? '') : '';

    final timeDisplay = _selectedHour12 != null
        ? '• $periodName $_selectedHour12'
        : '• সময় নির্বাচন করুন';

    final dateDisplay = hasDate
        ? '$dayLabel, ${_selectedFollowupDate!.day} $month ${_selectedFollowupDate!.year}'
        : 'তারিখ নির্বাচন করুন';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AddShopTheme.accentOrangeLight,
        borderRadius: BorderRadius.circular(AddShopTheme.radiusInput),
        border: Border.all(
          color: AddShopTheme.accentOrange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_available_rounded,
            size: 20,
            color: AddShopTheme.accentOrange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scheduled Revisit Date & Time',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AddShopTheme.accentOrangeDark,
                  ),
                ),
                Text(
                  '$dateDisplay $timeDisplay',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AddShopTheme.accentOrangeDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section Header helper
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: AddShopTheme.primaryTealLight,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AddShopTheme.primaryTeal,
            size: 18,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AddShopTheme.textDarkSlate,
          ),
        ),
      ],
    );
  }

  /// Input Decoration Builder with floating labels and teal focus glow
  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData prefixIcon,
    Color accentColor = AddShopTheme.primaryTeal,
    Widget? suffixWidget,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 13,
        color: AddShopTheme.textMuted,
      ),
      floatingLabelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: accentColor,
      ),
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 13,
        color: AddShopTheme.textPlaceholder,
      ),
      prefixIcon: Icon(prefixIcon, size: 20, color: accentColor),
      suffixIcon: suffixWidget,
      fillColor: Colors.white,
      filled: true,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AddShopTheme.radiusInput),
        borderSide: const BorderSide(color: AddShopTheme.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AddShopTheme.radiusInput),
        borderSide: BorderSide(color: accentColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AddShopTheme.radiusInput),
        borderSide: const BorderSide(color: AddShopTheme.errorRed, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AddShopTheme.radiusInput),
        borderSide: const BorderSide(color: AddShopTheme.errorRed, width: 2),
      ),
    );
  }

  /// Sticky Bottom Action Bar
  Widget _buildStickyBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AddShopTheme.cardBorder)),
        boxShadow: AddShopTheme.stickyBottomShadow,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Primary Action Button (Gradient, 54px height, soft shadow)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isAgreed
                        ? [
                            AddShopTheme.primaryTeal,
                            AddShopTheme.primaryTealDark,
                          ]
                        : [
                            AddShopTheme.accentOrange,
                            AddShopTheme.accentOrangeDark,
                          ],
                  ),
                  borderRadius: BorderRadius.circular(AddShopTheme.radiusButton),
                  boxShadow: _isAgreed
                      ? AddShopTheme.buttonShadow
                      : [
                          BoxShadow(
                            color: AddShopTheme.accentOrange.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AddShopTheme.radiusButton),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isAgreed
                              ? Icons.verified_rounded
                              : Icons.schedule_send_rounded,
                          size: 20,
                        ),
                  label: Text(
                    _isAgreed
                        ? 'Register Agreed Shop & Generate Code'
                        : 'Save Follow-up Shop',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _onSubmit,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Secondary Action Button (Save as Offline Draft)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AddShopTheme.primaryTealDark,
                  side: const BorderSide(
                    color: AddShopTheme.primaryTeal,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AddShopTheme.radiusButton),
                  ),
                ),
                icon: const Icon(Icons.drafts_outlined, size: 18),
                label: const Text(
                  'Save as Offline Draft',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _isSubmitting ? null : _saveOfflineDraft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
