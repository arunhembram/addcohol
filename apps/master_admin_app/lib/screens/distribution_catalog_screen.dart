import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

class DistributionCatalogScreen extends StatefulWidget {
  const DistributionCatalogScreen({super.key});

  @override
  State<DistributionCatalogScreen> createState() =>
      _DistributionCatalogScreenState();
}

class _DistributionCatalogScreenState
    extends State<DistributionCatalogScreen> {
  late List<DistributionMaterial> _materials;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  void _loadMaterials() {
    setState(() {
      _materials = List.from(CanonicalZones.getAllMaterials());
    });
  }

  void _showAddMaterialModal() {
    final nameController = TextEditingController();
    String targetType = 'all';
    int quantity = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Distribution Material\nনতুন বিতরণ সামগ্রী যোগ করুন',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Material Name / সামগ্রীর নাম',
                  hintText: 'e.g. Cello Tape, Glue Stick, Marker Pen',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Applicable To / কার জন্য প্রযোজ্য:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All Businesses (সব দোকান)'),
                    selected: targetType == 'all',
                    selectedColor: const Color(0xFF0F9D8A).withValues(alpha: 0.15),
                    onSelected: (val) {
                      if (val) setModalState(() => targetType = 'all');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Shops Only (শুধু দোকান)'),
                    selected: targetType == 'shop',
                    selectedColor: Colors.blue.withValues(alpha: 0.15),
                    onSelected: (val) {
                      if (val) setModalState(() => targetType = 'shop');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Saloons Only (শুধু সেলুন)'),
                    selected: targetType == 'saloon',
                    selectedColor: Colors.purple.withValues(alpha: 0.15),
                    onSelected: (val) {
                      if (val) setModalState(() => targetType = 'saloon');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Default Quantity per Shop: ',
                    style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: quantity > 1
                        ? () => setModalState(() => quantity--)
                        : null,
                  ),
                  Text(
                    '$quantity',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setModalState(() => quantity++),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F2A43),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final newMat = DistributionMaterial(
                      id: 'mat-${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      targetBusinessType: targetType,
                      defaultQuantity: quantity,
                      createdAt: DateTime.now(),
                    );
                    CanonicalZones.addMaterial(newMat);
                    Navigator.of(ctx).pop();
                    _loadMaterials();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added "$name" to Central Material Catalog'),
                        backgroundColor: const Color(0xFF2E7D32),
                      ),
                    );
                  },
                  child: const Text(
                    'Save Material / সেভ করুন',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteMaterial(DistributionMaterial material) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Material?'),
        content: Text(
          'Are you sure you want to remove "${material.name}" from the global catalog?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              CanonicalZones.removeMaterial(material.id);
              Navigator.of(ctx).pop();
              _loadMaterials();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Distribution Materials Catalog / বিতরণ ক্যাটালগ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: _materials.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 64, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  const Text(
                    'No Materials Found\nকোনো বিতরণ সামগ্রী নেই',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showAddMaterialModal,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Material'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _materials.length,
              itemBuilder: (context, index) {
                final mat = _materials[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    backgroundColor: Colors.white,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF006874).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            color: Color(0xFF006874),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mat.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _buildTargetBadge(mat.targetBusinessType),
                                const SizedBox(width: 8),
                                Text(
                                  'Default: ${mat.defaultQuantity} unit/shop',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteMaterial(mat),
                      ),
                    ],
                  ),
                ),
              );
            },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F2A43),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Material / নতুন সামগ্রী'),
        onPressed: _showAddMaterialModal,
      ),
    );
  }

  Widget _buildTargetBadge(String target) {
    Color bg;
    Color text;
    String label;

    switch (target) {
      case 'shop':
        bg = Colors.blue.withValues(alpha: 0.12);
        text = Colors.blue.shade700;
        label = 'Shops Only';
        break;
      case 'saloon':
        bg = Colors.purple.withValues(alpha: 0.12);
        text = Colors.purple.shade700;
        label = 'Saloons Only';
        break;
      default:
        bg = const Color(0xFF0F9D8A).withValues(alpha: 0.12);
        text = const Color(0xFF0F9D8A);
        label = 'All Businesses';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }
}
