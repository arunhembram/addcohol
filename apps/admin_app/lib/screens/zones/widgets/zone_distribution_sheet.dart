import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import '../services/zone_qr_pdf_service.dart';
import 'zone_company_tasks_table.dart';

class ZoneDistributionSheet extends StatefulWidget {
  final Zone zone;
  final List<Shop> shops;

  const ZoneDistributionSheet({
    super.key,
    required this.zone,
    required this.shops,
  });

  static Future<void> show(
    BuildContext context, {
    required Zone zone,
    required List<Shop> shops,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ZoneDistributionSheet(zone: zone, shops: shops),
    );
  }

  @override
  State<ZoneDistributionSheet> createState() => _ZoneDistributionSheetState();
}

class _ZoneDistributionSheetState extends State<ZoneDistributionSheet> {
  late List<MaterialDistributionRun> _materialRuns;
  late List<CompanyAdDistributionRun> _adRuns;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _refreshRuns();
  }

  void _refreshRuns() {
    setState(() {
      _materialRuns = CanonicalZones.getMaterialRuns(widget.zone.id);
      _adRuns = CanonicalZones.getCompanyAdRuns(widget.zone.id);
    });
  }

  Future<void> _handleGeneratePdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      await ZoneQrPdfService.generateAndPrintZoneQrs(
        zone: widget.zone,
        shops: widget.shops,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating QR PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zone Distribution Operations',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${widget.zone.name} • ${widget.shops.length} Total Registered Shops',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 24, thickness: 1, color: Color(0xFFE2E8F0)),

          // Content body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              children: [
                // 1. Zone QR Scanner A4 PDF Generation Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F2A43).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          color: Color(0xFF0F2A43),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Shop Distribution QRs (A4 PDF)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Generate 1 page per shop with shop name & QR code for printing / xerox.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F2A43),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isGeneratingPdf ? null : _handleGeneratePdf,
                        icon: _isGeneratingPdf
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Print PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Store Supply Runs Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '📦 Store Supplies (Master Catalog)',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${_materialRuns.length} Materials in Catalog',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F9D8A)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (_materialRuns.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'No supply materials defined in Master Catalog.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  )
                else
                  for (final run in _materialRuns) _buildMaterialRunCard(run),

                const SizedBox(height: 24),

                // 3. Company Ad Campaigns Section & Task Pipeline Table
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '📢 Booked Ad Campaigns & Task Pipeline',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${_adRuns.length} Booked Slots',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                ZoneCompanyTasksTable(
                  zoneId: widget.zone.id,
                  onStateChanged: _refreshRuns,
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialRunCard(MaterialDistributionRun run) {
    final isComplete = run.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: run.status == 'active' ? const Color(0xFF0F9D8A).withValues(alpha: 0.5) : const Color(0xFFCBD5E1),
          width: run.status == 'active' ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F9D8A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF0F9D8A), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distribute ${run.materialName}',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Target: ${run.targetBusinessType.toUpperCase()} • ${run.totalTargetCount} Stores',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    run.status == 'active' ? 'Active' : 'Off',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: run.status == 'active' ? const Color(0xFF0F9D8A) : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: run.status == 'active',
                    activeThumbColor: const Color(0xFF0F9D8A),
                    activeTrackColor: const Color(0xFF0F9D8A).withValues(alpha: 0.35),
                    onChanged: (val) {
                      CanonicalZones.toggleMaterialRun(widget.zone.id, run.id, val);
                      _refreshRuns();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: run.progressFraction,
              backgroundColor: const Color(0xFFE2E8F0),
              color: isComplete ? Colors.green : const Color(0xFF0F9D8A),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${run.progressPercent}% Complete (${run.deliveredCount} Delivered, ${run.goneCount} Gone)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
              Text(
                'Remaining: ${run.totalTargetCount - run.completedOrGoneCount}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }


}
