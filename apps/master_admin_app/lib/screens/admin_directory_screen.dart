import 'dart:async';
import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/master_admin_providers.dart';

class AdminDirectoryScreen extends ConsumerStatefulWidget {
  const AdminDirectoryScreen({super.key});

  @override
  ConsumerState<AdminDirectoryScreen> createState() => _AdminDirectoryScreenState();
}

class _AdminDirectoryScreenState extends ConsumerState<AdminDirectoryScreen> {
  bool _isCreatingCode = false;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    CanonicalZones.zonesRevision.addListener(_onZonesRevisionChanged);
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final updated = await DistributionSyncService.fetchRemoteState();
      if (updated && mounted) {
        ref.invalidate(adminsListProvider);
      }
    });
  }

  void _onZonesRevisionChanged() {
    if (mounted) {
      ref.invalidate(adminsListProvider);
    }
  }

  @override
  void dispose() {
    CanonicalZones.zonesRevision.removeListener(_onZonesRevisionChanged);
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _createNewAdminCode() async {
    setState(() => _isCreatingCode = true);
    try {
      final repo = ref.read(masterAdminRepositoryProvider);
      final newAdmin = await repo.createAdminCode();
      ref.invalidate(adminsListProvider);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text('New Admin Code Created!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'A new unclaimed Admin Code has been generated. This account currently has no name until the admin logs in.',
                  style: TextStyle(fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F2A43),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Text(
                    newAdmin.displayId ?? '10001',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Provide this 5-digit code to the new administrator. When they log in on the Admin App, their full name and credentials will bind to this entry automatically.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy Code'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: newAdmin.displayId ?? '10001'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Admin Code copied to clipboard!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F2A43)),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate admin code: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingCode = false);
    }
  }

  void _showSimulateLoginDialog(UserProfile admin) {
    final nameCtrl = TextEditingController(text: 'Rohan Sharma');
    final phoneCtrl = TextEditingController(text: '+91 98305 66778');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.login_rounded, color: Color(0xFF0F2A43)),
            const SizedBox(width: 8),
            Text('Admin Login for Code: ${admin.displayId}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simulate admin first login with this code. Once logged in, the code entry will convert into their profile name:',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Admin Full Name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F2A43)),
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(masterAdminRepositoryProvider);
              await repo.pairAdminCode(
                admin.displayId ?? '',
                fullName: nameCtrl.text.trim(),
                phoneNumber: phoneCtrl.text.trim(),
              );
              ref.invalidate(adminsListProvider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Code ${admin.displayId ?? ""} paired to "${nameCtrl.text.trim()}"!'),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
              }
            },
            child: const Text('Complete Login & Bind Name'),
          ),
        ],
      ),
    );
  }

  void _showAdminContactSheet(String name, String phone) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0xFFE0E7FF),
                    child: Icon(Icons.person, color: Color(0xFF4338CA), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          phone.isNotEmpty ? phone : 'No phone number registered',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.call, color: Colors.green.shade700, size: 20),
                ),
                title: const Text('Direct Phone Call / সরাসরি কল', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(phone),
                onTap: () async {
                  Navigator.pop(ctx);
                  final clean = phone.replaceAll(' ', '');
                  final uri = Uri.parse('tel:$clean');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF16A34A), size: 20),
                ),
                title: const Text('WhatsApp Chat / হোয়াটসঅ্যাপ চ্যাট', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Send direct message on WhatsApp'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final clean = phone.replaceAll('+', '').replaceAll(' ', '').replaceAll('-', '');
                  final uri = Uri.parse('https://wa.me/$clean');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.copy_rounded, color: Colors.blue.shade700, size: 20),
                ),
                title: const Text('Copy Phone Number / নম্বর কপি করুন', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Copy to clipboard'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: phone));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Phone number copied to clipboard!')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adminsAsync = ref.watch(adminsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Directory & Access Codes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'অ্যাডমিন তালিকা ও লগইন কোড পরিচালনা',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Admins',
            onPressed: () async {
              await DistributionSyncService.fetchRemoteState();
              ref.invalidate(adminsListProvider);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 1. Generate Admin Code CTA Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2A43), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.vpn_key_rounded, color: Colors.amberAccent, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Generate Admin Code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Creates a new slot with code only. Name binds when admin logs in.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: const Color(0xFF0F2A43),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isCreatingCode
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F2A43)),
                        )
                      : const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'Create Code',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: _isCreatingCode ? null : _createNewAdminCode,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. Admin List Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Registered & Pending Admins / অ্যাডমিন তালিকা',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                label: const Text('Manual KYC Form', style: TextStyle(fontSize: 12)),
                onPressed: () => context.push('/admins/create'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 3. Admin Cards List
          adminsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => AppErrorView(
              title: 'Failed to load admins',
              message: err.toString(),
              onRetry: () => ref.refresh(adminsListProvider),
            ),
            data: (admins) {
              if (admins.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No admins found. Click "Create Code" to generate the first admin code.'),
                  ),
                );
              }

              return Column(
                children: admins.map((admin) {
                  final bool isPending = admin.fullName.trim().isEmpty;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPending ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                        width: isPending ? 1.5 : 1,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: isPending ? const Color(0xFFF1F5F9) : const Color(0xFFE0E7FF),
                                child: Icon(
                                  isPending ? Icons.vpn_key_outlined : Icons.person,
                                  color: isPending ? const Color(0xFF64748B) : const Color(0xFF4338CA),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            isPending
                                                ? 'Admin Code: ${admin.displayId}'
                                                : admin.fullName,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isPending ? Colors.amber.shade100 : Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isPending ? '⚪ Pending Login' : '🟢 Active Admin',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isPending ? Colors.amber.shade900 : Colors.green.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      isPending
                                          ? 'Awaiting admin login with this code • Name will bind automatically'
                                          : 'Code / ID: ${admin.displayId ?? ""} • ${(admin.phoneNumber ?? "").isNotEmpty ? admin.phoneNumber! : "No phone"}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isPending ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Call Sign (📞) button if active
                              if (!isPending) ...[
                                IconButton(
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFFDCFCE7),
                                    foregroundColor: const Color(0xFF15803D),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  icon: const Icon(Icons.phone, size: 18),
                                  tooltip: 'Call / Contact Admin',
                                  onPressed: () => _showAdminContactSheet(
                                    admin.fullName,
                                    (admin.phoneNumber ?? '').isNotEmpty ? admin.phoneNumber! : '+91 98301 11223',
                                  ),
                                ),
                              ],
                            ],
                          ),

                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),

                          // Action Row
                          Row(
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.copy_rounded, size: 14),
                                label: Text('Copy Code (${admin.displayId ?? ""})', style: const TextStyle(fontSize: 11.5)),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: admin.displayId ?? ''));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Code ${admin.displayId ?? ""} copied!')),
                                  );
                                },
                              ),
                              const Spacer(),
                              if (isPending) ...[
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F2A43),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.login_rounded, size: 14),
                                  label: const Text('Simulate Admin Login', style: TextStyle(fontSize: 11.5)),
                                  onPressed: () => _showSimulateLoginDialog(admin),
                                ),
                              ] else ...[
                                TextButton.icon(
                                  icon: const Icon(Icons.assignment_ind_outlined, size: 16),
                                  label: const Text('Assign Zones', style: TextStyle(fontSize: 12)),
                                  onPressed: () => context.push('/admins/assign?adminId=${admin.id}'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
