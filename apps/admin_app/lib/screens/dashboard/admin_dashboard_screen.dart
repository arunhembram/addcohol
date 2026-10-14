import 'dart:async';
import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_state_providers.dart';
import '../zones/services/zone_qr_pdf_service.dart';
import '../zones/widgets/zone_company_tasks_table.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  Timer? _syncTimer;
  DateTime? _lastLocalToggleTime;

  @override
  void initState() {
    super.initState();
    CanonicalZones.syncWithRemote();
    int lastZonesRev = CanonicalZones.zonesRevision.value;
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      if (_lastLocalToggleTime != null &&
          DateTime.now().difference(_lastLocalToggleTime!).inSeconds < 4) {
        return;
      }
      await CanonicalZones.syncWithRemote();
      if (!mounted) return;
      if (lastZonesRev != CanonicalZones.zonesRevision.value) {
        lastZonesRev = CanonicalZones.zonesRevision.value;
        ref.invalidate(controlledZonesProvider);
        ref.invalidate(controlledEmployeesProvider);
      }
      for (final z in CanonicalZones.all) {
        ref.read(zoneDistributionModeStateProvider(z.id).notifier).state =
            CanonicalZones.isDistributionModeActive(z.id);
        ref.read(zoneDistributionCategoriesProvider(z.id).notifier).state =
            CanonicalZones.getDistributionCategories(z.id);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(adminAuthProvider);
    final admin = authState.currentAdmin ??
        UserProfile(
          id: 'admin-10001',
          email: 'subhasis.sen@shopad.local',
          fullName: 'Subhasis Sen',
          role: UserRole.admin,
          phoneNumber: '+91 98765 43210',
          displayId: '10001',
          createdAt: DateTime(2026, 1, 1),
        );

    final zonesAsync = ref.watch(controlledZonesProvider);
    final employeesAsync = ref.watch(controlledEmployeesProvider);
    final shopsAsync = ref.watch(controlledShopsProvider);
    final followupsAsync = ref.watch(controlledFollowupsProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            const Text('ShopAd Admin'),
            const SizedBox(width: AppSpacing.sm),
            AppBadge(
              label: 'ID: ${admin.displayId ?? "10001"}',
              variant: AppBadgeVariant.info,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle Light/Dark Theme',
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
          IconButton(
            tooltip: 'System Health',
            icon: const Icon(Icons.health_and_safety_outlined),
            onPressed: () => context.push('/health'),
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(adminAuthProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              // Already here
              break;
            case 1:
              context.push('/employees');
              break;
            case 2:
              context.push('/shops');
              break;
            case 3:
              context.push('/performance');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Zones',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Employees',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Shops',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Performance',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(controlledZonesProvider);
          ref.invalidate(controlledEmployeesProvider);
          ref.invalidate(controlledShopsProvider);
          ref.invalidate(controlledFollowupsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Admin Profile Card
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        admin.fullName.isNotEmpty
                            ? admin.fullName.trim()[0].toUpperCase()
                            : 'A',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                admin.fullName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              AppBadge(
                                label: 'Admin',
                                variant: AppBadgeVariant.success,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '5-Digit Admin ID: ${admin.displayId ?? "10001"} • ${admin.email}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.neutral600,
                            ),
                          ),
                          if (admin.phoneNumber != null)
                            Text(
                              'Registered Mobile: ${admin.phoneNumber}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.neutral500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 2. Controlled Jurisdiction KPI Counters
              Row(
                children: [
                  Expanded(
                    child: _KpiTile(
                      title: 'Controlled Zones',
                      value: zonesAsync.when(
                        data: (zones) => '${zones.length}',
                        loading: () => '...',
                        error: (err, st) => '0',
                      ),
                      icon: Icons.map_outlined,
                      color: AppColors.primary,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _KpiTile(
                      title: 'Managed Staff',
                      value: employeesAsync.when(
                        data: (list) => '${list.length}',
                        loading: () => '...',
                        error: (err, st) => '0',
                      ),
                      icon: Icons.people_outline,
                      color: AppColors.secondary,
                      onTap: () => context.push('/employees'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _KpiTile(
                      title: 'Controlled Shops',
                      value: shopsAsync.when(
                        data: (shops) => '${shops.length}',
                        loading: () => '...',
                        error: (err, st) => '0',
                      ),
                      icon: Icons.store_outlined,
                      color: AppColors.success,
                      onTap: () => context.push('/shops'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _KpiTile(
                      title: 'Active Follow-ups',
                      value: followupsAsync.when(
                        data: (fups) => '${fups.length}',
                        loading: () => '...',
                        error: (err, st) => '0',
                      ),
                      icon: Icons.checklist_outlined,
                      color: AppColors.warning,
                      onTap: () => context.push('/shops'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // 3. Controlled Zone List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Controlled Zones',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'You only have jurisdiction over zones assigned by Master Admin',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.neutral600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // 4. Controlled Zone Cards
              zonesAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Error loading controlled zones: $error',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                data: (zones) {
                  if (zones.isEmpty) {
                    return AppCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        children: [
                          const Icon(Icons.map, size: 48, color: AppColors.neutral400),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'No zones currently assigned to your account.',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Contact the Master Admin to allocate zone assignments.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.neutral600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: zones.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final zone = zones[index];
                      Color zoneColor;
                      try {
                        final hex = zone.colorHex.replaceAll('#', '');
                        zoneColor = Color(int.parse('FF$hex', radix: 16));
                      } catch (_) {
                        zoneColor = AppColors.primary;
                      }
                      final allShops = shopsAsync.asData?.value ?? [];
                      final zoneShops = allShops.where((s) => s.zoneId == zone.id).toList();

                      return AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: zoneColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    zone.name,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                AppBadge(
                                  label: '${zone.shopCount} Shops',
                                  variant: AppBadgeVariant.info,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                AppBadge(
                                  label: zone.isActive ? 'Active' : 'Inactive',
                                  variant: zone.isActive
                                      ? AppBadgeVariant.success
                                      : AppBadgeVariant.neutral,
                                ),
                              ],
                            ),
                            if (zone.description != null && zone.description!.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                zone.description!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.neutral600,
                                ),
                              ),
                            ],

                            // --- SECTION 1: COMPANY AD CAMPAIGNS & TASK VIEW (বিজ্ঞাপন ক্যাম্পেইন বিতরণ) ---
                            Container(
                              margin: const EdgeInsets.only(top: AppSpacing.sm),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(AppRadii.md),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.campaign_rounded, color: Color(0xFF0284C7), size: 18),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'COMPANY AD CAMPAIGNS & TASK PIPELINE (বিজ্ঞাপন ক্যাম্পেইন বিতরণ)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F2A43),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ZoneCompanyTasksTable(
                                    zoneId: zone.id,
                                    onStateChanged: () => setState(() {}),
                                  ),
                                ],
                              ),
                            ),

                            // --- SECTION 2: DISTRIBUTION OF MATERIALS (দোকানের সামগ্রী বিতরণ — আলাদা বার) ---
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(AppRadii.md),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.inventory_2_rounded, color: Color(0xFF0F9D8A), size: 18),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'DISTRIBUTION OF MATERIALS (দোকানের সামগ্রী বিতরণ)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F2A43),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  Builder(
                                    builder: (context) {
                                      final matRuns = CanonicalZones.getMaterialRuns(zone.id);
                                      if (matRuns.isEmpty) {
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 8),
                                          child: Text(
                                            'মাস্টার ক্যাটালগে কোনো সামগ্রী পাওয়া যায়নি। মাস্টার অ্যাডমিন ক্যাটালগে সামগ্রী তৈরি করলে এখানে স্বয়ংক্রিয়ভাবে দেখাবে।',
                                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        );
                                      }

                                      return Column(
                                        children: [
                                          for (final mat in matRuns) ...[
                                            Container(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: mat.status == 'active'
                                                      ? const Color(0xFF0F9D8A).withValues(alpha: 0.5)
                                                      : const Color(0xFFCBD5E1),
                                                  width: mat.status == 'active' ? 1.5 : 1,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.all(6),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF0F9D8A).withValues(alpha: 0.1),
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: const Icon(Icons.inventory_2_outlined,
                                                            size: 15, color: Color(0xFF0F9D8A)),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              'Distribute ${mat.materialName}',
                                                              style: const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight: FontWeight.bold,
                                                                color: Color(0xFF0F172A),
                                                              ),
                                                            ),
                                                            Text(
                                                              'Target: ${mat.targetBusinessType.toUpperCase()}',
                                                              style: const TextStyle(
                                                                fontSize: 10.5,
                                                                color: Color(0xFF64748B),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),

                                                      // Independent Toggle Switch for this Material Run
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            mat.status == 'active' ? 'Active' : 'Off',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                              color: mat.status == 'active'
                                                                  ? const Color(0xFF0F9D8A)
                                                                  : const Color(0xFF94A3B8),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Switch(
                                                            value: mat.status == 'active',
                                                            activeThumbColor: const Color(0xFF0F9D8A),
                                                            activeTrackColor:
                                                                const Color(0xFF0F9D8A).withValues(alpha: 0.35),
                                                            onChanged: (val) {
                                                              CanonicalZones.toggleMaterialRun(zone.id, mat.id, val);
                                                              setState(() {});
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(val
                                                                      ? '✅ ${mat.materialName} বিতরণ চালু হলো'
                                                                      : '⏸️ ${mat.materialName} বিতরণ বন্ধ করা হলো'),
                                                                  duration: const Duration(seconds: 2),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),

                                                  // Live Progress Bar
                                                  if (mat.status == 'active' || mat.distributedShopIds.isNotEmpty) ...[
                                                    const SizedBox(height: 6),
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: LinearProgressIndicator(
                                                        value: mat.progressFraction,
                                                        minHeight: 5,
                                                        backgroundColor: const Color(0xFFE2E8F0),
                                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F9D8A)),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${mat.progressPercent}% Progress (${mat.completedOrGoneCount}/${mat.totalTargetCount} Shops)',
                                                      style: const TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF0F9D8A),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            // --- SECTION 3: ASSIGNED EMPLOYEES (জোনে কর্মী নিয়োজিত) ---
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(AppRadii.md),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.badge_rounded, color: Color(0xFF6366F1), size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            'ASSIGNED EMPLOYEES (জোনে কর্মী নিয়োজিত)',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F2A43),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Assign Employee Dropdown Menu
                                      Builder(
                                        builder: (ctx) {
                                          final assignedEmps = CanonicalZones.getZoneAssignedEmployees(zone.id);
                                          final allManaged = CanonicalZones.getManagedEmployees(adminId: admin.id);
                                          final available = allManaged.where((e) => !assignedEmps.any((ae) => ae.id == e.id || ae.displayId == e.displayId)).toList();

                                          return PopupMenuButton<UserProfile>(
                                            tooltip: 'Assign Employee to ${zone.name}',
                                            offset: const Offset(0, 36),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF6366F1),
                                                borderRadius: BorderRadius.circular(AppRadii.sm),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.person_add_alt_1_rounded, size: 14, color: Colors.white),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Assign Employee',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  Icon(Icons.arrow_drop_down_rounded, size: 16, color: Colors.white),
                                                ],
                                              ),
                                            ),
                                            onSelected: (selectedEmp) {
                                              CanonicalZones.assignEmployeeToZone(zone.id, selectedEmp.id);
                                              ref.invalidate(controlledEmployeesProvider);
                                              ref.invalidate(controlledZonesProvider);
                                              setState(() {});
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '✅ Assigned ${selectedEmp.fullName.isEmpty ? "Code ${selectedEmp.displayId}" : selectedEmp.fullName} to ${zone.name}',
                                                  ),
                                                  backgroundColor: const Color(0xFF10B981),
                                                ),
                                              );
                                            },
                                            itemBuilder: (ctx) {
                                              if (available.isEmpty) {
                                                return [
                                                  const PopupMenuItem<UserProfile>(
                                                    enabled: false,
                                                    child: Text(
                                                      'No available employees to assign.\nCreate an employee code first.',
                                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                                    ),
                                                  ),
                                                ];
                                              }
                                              return available.map((emp) {
                                                final isUnpaired = emp.fullName.trim().isEmpty;
                                                return PopupMenuItem<UserProfile>(
                                                  value: emp,
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        isUnpaired ? Icons.qr_code_rounded : Icons.person_rounded,
                                                        size: 16,
                                                        color: isUnpaired ? Colors.orange : const Color(0xFF6366F1),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          isUnpaired
                                                              ? 'Code: ${emp.displayId} (Unpaired Code)'
                                                              : '${emp.fullName} (${emp.displayId})',
                                                          style: const TextStyle(fontSize: 12),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList();
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // List of assigned employees in this zone
                                  Builder(
                                    builder: (ctx) {
                                      final assignedEmps = CanonicalZones.getZoneAssignedEmployees(zone.id);
                                      if (assignedEmps.isEmpty) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(AppRadii.sm),
                                            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.person_off_outlined, size: 16, color: AppColors.neutral500),
                                              SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  '⚪ No Employee Assigned • Use "Assign Employee" to assign staff',
                                                  style: TextStyle(fontSize: 11.5, color: AppColors.neutral600),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      return Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: assignedEmps.map((emp) {
                                          final isUnpaired = emp.fullName.trim().isEmpty;
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                                              boxShadow: const [
                                                BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircleAvatar(
                                                  radius: 10,
                                                  backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                                  child: Text(
                                                    isUnpaired ? '#' : emp.fullName[0].toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF6366F1),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  isUnpaired ? 'Code: ${emp.displayId}' : emp.fullName,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Tooltip(
                                                  message: 'Unassign from this zone',
                                                  child: InkWell(
                                                    onTap: () {
                                                      CanonicalZones.unassignEmployeeFromZone(zone.id, emp.id);
                                                      ref.invalidate(controlledEmployeesProvider);
                                                      ref.invalidate(controlledZonesProvider);
                                                      setState(() {});
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Unassigned ${emp.fullName.isEmpty ? emp.displayId : emp.fullName} from ${zone.name}.',
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    child: const Padding(
                                                      padding: EdgeInsets.all(2.0),
                                                      child: Icon(Icons.close_rounded, size: 14, color: AppColors.neutral500),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: AppSpacing.sm),
                            const Divider(height: 1),
                            const SizedBox(height: AppSpacing.sm),

                            // Zone Bottom Actions: Print QR, Employees, View Map
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // 1. Print QR Scanners (A4 PDF) Button
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0F2A43),
                                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.print_outlined, size: 16, color: Color(0xFF0F2A43)),
                                  label: const Text(
                                    'Print QR (A4 PDF)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  onPressed: () {
                                    ZoneQrPdfService.generateAndPrintZoneQrs(
                                      zone: zone,
                                      shops: zoneShops,
                                    );
                                  },
                                ),

                                // 2. Manage Employees
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.people_outline, size: 16),
                                  label: const Text('Employees', style: TextStyle(fontSize: 12)),
                                  onPressed: () => context.push('/employees'),
                                ),

                                // 3. View Zone Map
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F2A43),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.map_rounded, size: 16),
                                  label: const Text('Zone Map', style: TextStyle(fontSize: 12)),
                                  onPressed: () =>
                                      context.push('/zones/${zone.id}/map'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _KpiTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _KpiTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.neutral400),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.neutral600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
