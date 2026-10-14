import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/cashfree_models.dart';
import '../services/cashfree_service.dart';

/// Modal dialog providing Cashfree Payment Gateway Checkout experience
class CashfreeCheckoutModal extends StatefulWidget {
  final double amount;
  final String orderTitle;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String? bookingId;
  final CashfreeService? service;

  const CashfreeCheckoutModal({
    super.key,
    required this.amount,
    required this.orderTitle,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail = 'billing@customer.com',
    this.bookingId,
    this.service,
  });

  /// Static helper to display the modal
  static Future<CashfreePaymentResult?> show(
    BuildContext context, {
    required double amount,
    required String orderTitle,
    required String customerName,
    required String customerPhone,
    String customerEmail = 'billing@customer.com',
    String? bookingId,
    CashfreeService? service,
  }) {
    return showModalBottomSheet<CashfreePaymentResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CashfreeCheckoutModal(
        amount: amount,
        orderTitle: orderTitle,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        bookingId: bookingId,
        service: service,
      ),
    );
  }

  @override
  State<CashfreeCheckoutModal> createState() => _CashfreeCheckoutModalState();
}

class _CashfreeCheckoutModalState extends State<CashfreeCheckoutModal> {
  static const Color brandNavy = Color(0xFF0F2A43);
  static const Color brandPurple = Color(0xFF5B36D6);
  static const Color brandTeal = Color(0xFF0F9D8A);

  late final CashfreeService _service;
  CashfreeOrder? _order;
  bool _isLoadingOrder = true;
  bool _isProcessingPayment = false;
  String _selectedTab = 'upi'; // 'upi', 'card', 'netbanking', 'wallet'

  // UPI Form
  final TextEditingController _upiController = TextEditingController(text: 'company@okaxis');

  // Card Form
  final TextEditingController _cardNumberController = TextEditingController(text: '4111 2222 3333 4444');
  final TextEditingController _cardExpiryController = TextEditingController(text: '12/28');
  final TextEditingController _cardCvvController = TextEditingController(text: '123');
  final TextEditingController _cardHolderController = TextEditingController();

  // Netbanking
  String _selectedBank = 'HDFC Bank';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CashfreeService();
    _cardHolderController.text = widget.customerName;
    _initOrder();
  }

  @override
  void dispose() {
    _upiController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  Future<void> _initOrder() async {
    try {
      final order = await _service.createOrder(
        orderAmount: widget.amount,
        customerDetails: CashfreeCustomerDetails(
          customerId: 'cust_${widget.customerPhone.hashCode.abs()}',
          customerName: widget.customerName,
          customerPhone: widget.customerPhone,
          customerEmail: widget.customerEmail,
        ),
        orderNote: widget.orderTitle,
        bookingId: widget.bookingId,
      );
      if (mounted) {
        setState(() {
          _order = order;
          _isLoadingOrder = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingOrder = false);
      }
    }
  }

  Future<void> _processPayment({
    required String method,
    String? upiId,
    String? cardLast4,
    String? bankName,
  }) async {
    setState(() => _isProcessingPayment = true);

    // 1. Show processing state
    await Future.delayed(const Duration(milliseconds: 900));

    // 2. 3D Secure / Bank OTP Simulation for Cards and Netbanking
    if (method == 'CARD' || method == 'NETBANKING') {
      if (!mounted) return;
      final otpSuccess = await _showSimulatedOtpSheet(method);
      if (otpSuccess != true) {
        setState(() => _isProcessingPayment = false);
        return;
      }
    }

    // 3. Finalize payment result
    final orderId = _order?.orderId ?? 'CF_ORD_${DateTime.now().millisecondsSinceEpoch}';
    final result = _service.simulateSuccessfulPayment(
      orderId: orderId,
      amount: widget.amount,
      paymentMethod: method,
      upiId: upiId,
      cardLast4: cardLast4,
      bankName: bankName,
    );

    if (mounted) {
      setState(() => _isProcessingPayment = false);
      _showSuccessSheet(result);
    }
  }

  Future<bool?> _showSimulatedOtpSheet(String method) {
    final otpController = TextEditingController(text: '123456');
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.shield_rounded, color: brandPurple, size: 24),
            const SizedBox(width: 8),
            Text(
              method == 'CARD' ? '3D Secure Verification' : 'Net Banking Authentication',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A one-time password (OTP) was sent to ${widget.customerPhone}.',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Enter OTP',
                hintText: '123456',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.password_rounded),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '🧪 Sandbox Test OTP: 123456',
              style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Verify & Authorize'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSheet(CashfreePaymentResult result) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 54),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Successful!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: brandNavy),
            ),
            const SizedBox(height: 4),
            Text(
              '₹${widget.amount.toStringAsFixed(0)} paid via Cashfree ${result.paymentMethod}',
              style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Transaction ID', result.cfPaymentId ?? 'N/A'),
                  const Divider(height: 12),
                  _buildDetailRow('Cashfree Order ID', result.orderId),
                  const Divider(height: 12),
                  _buildDetailRow('Bank Reference (UTR)', result.referenceId ?? 'N/A'),
                  const Divider(height: 12),
                  _buildDetailRow('Paid At', DateTime.now().toString().substring(0, 19)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop(); // Close success bottom sheet
                  Navigator.of(context).pop(result); // Return result to caller
                },
                child: const Text('Proceed to Confirmed Campaign', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: brandNavy)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header with Cashfree branding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: brandPurple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.payment_rounded, color: brandPurple, size: 16),
                          SizedBox(width: 4),
                          Text('Cashfree', style: TextStyle(fontWeight: FontWeight.w900, color: brandPurple, fontSize: 13)),
                          Text(' Payments', style: TextStyle(fontWeight: FontWeight.w600, color: brandNavy, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFFB74D)),
                      ),
                      child: const Text('SANDBOX', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFE65100))),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Order Amount Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.orderTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: brandNavy)),
                    const SizedBox(height: 2),
                    Text('${widget.customerName} • ${widget.customerPhone}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('TOTAL PAYABLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text('₹${widget.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: brandNavy)),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Payment Methods Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildTabButton('upi', 'UPI / QR', Icons.qr_code_2_rounded),
                const SizedBox(width: 8),
                _buildTabButton('card', 'Cards', Icons.credit_card_rounded),
                const SizedBox(width: 8),
                _buildTabButton('netbanking', 'NetBanking', Icons.account_balance_rounded),
              ],
            ),
          ),

          // Active Payment Method Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _isLoadingOrder
                  ? const Center(child: CircularProgressIndicator())
                  : _buildActivePaymentBody(),
            ),
          ),

          // Security footer
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_rounded, size: 12, color: Colors.grey),
                SizedBox(width: 4),
                Text('256-bit SSL Encrypted • RBI Licensed Payment Aggregator', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String id, String label, IconData icon) {
    final isSelected = _selectedTab == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? brandNavy : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.black87),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivePaymentBody() {
    if (_isProcessingPayment) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: brandPurple),
            const SizedBox(height: 20),
            const Text('Connecting with Cashfree Gateway...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            const Text('Please do not refresh or press back', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 30),
          ],
        ),
      );
    }

    switch (_selectedTab) {
      case 'upi':
        return _buildUpiBody();
      case 'card':
        return _buildCardBody();
      case 'netbanking':
        return _buildNetBankingBody();
      default:
        return _buildUpiBody();
    }
  }

  Widget _buildUpiBody() {
    final upiUrl = 'upi://pay?pa=cashfree.test@icici&pn=Antigravity&am=${widget.amount}&cu=INR';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Scan QR Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              QrImageView(
                data: upiUrl,
                version: QrVersions.auto,
                size: 160,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner_rounded, size: 14, color: brandPurple),
                  SizedBox(width: 4),
                  Text('Scan with GPay, PhonePe, Paytm', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: brandPurple)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Quick UPI Apps
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildUpiAppChip('GPay', Colors.blue, () => _processPayment(method: 'UPI', upiId: 'gpay@okhdfcbank')),
            _buildUpiAppChip('PhonePe', const Color(0xFF5F259F), () => _processPayment(method: 'UPI', upiId: 'phonepe@ybl')),
            _buildUpiAppChip('Paytm', const Color(0xFF00B9F1), () => _processPayment(method: 'UPI', upiId: 'paytm@paytm')),
            _buildUpiAppChip('BHIM', const Color(0xFF00796B), () => _processPayment(method: 'UPI', upiId: 'bhim@upi')),
          ],
        ),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),

        // Enter UPI ID
        TextField(
          controller: _upiController,
          decoration: InputDecoration(
            labelText: 'Enter UPI ID (VPA)',
            hintText: 'yourname@bank',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward_rounded, color: brandPurple),
              onPressed: () => _processPayment(method: 'UPI', upiId: _upiController.text.trim()),
            ),
          ),
        ),

        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _processPayment(method: 'UPI', upiId: _upiController.text.trim()),
            child: Text('Pay ₹${widget.amount.toStringAsFixed(0)} via UPI', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildUpiAppChip(String name, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(name, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildCardBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _cardNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(16),
          ],
          decoration: const InputDecoration(
            labelText: 'Card Number',
            hintText: '4111 2222 3333 4444',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.credit_card_rounded),
            suffixIcon: Icon(Icons.credit_score_rounded, color: Colors.blue),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cardExpiryController,
                decoration: const InputDecoration(
                  labelText: 'Expiry (MM/YY)',
                  hintText: '12/28',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _cardCvvController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'CVV',
                  hintText: '123',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cardHolderController,
          decoration: const InputDecoration(
            labelText: 'Cardholder Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final last4 = _cardNumberController.text.length >= 4
                  ? _cardNumberController.text.substring(_cardNumberController.text.length - 4)
                  : '4444';
              _processPayment(method: 'CARD', cardLast4: last4);
            },
            child: Text('Pay ₹${widget.amount.toStringAsFixed(0)} via Card', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildNetBankingBody() {
    const popularBanks = [
      'HDFC Bank',
      'State Bank of India',
      'ICICI Bank',
      'Axis Bank',
      'Kotak Mahindra',
      'Punjab National Bank',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Popular Banks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: brandNavy)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: popularBanks.map((bank) {
            final isSelected = _selectedBank == bank;
            return ChoiceChip(
              label: Text(bank, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
              selected: isSelected,
              selectedColor: brandPurple,
              onSelected: (_) => setState(() => _selectedBank = bank),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedBank,
          decoration: const InputDecoration(
            labelText: 'All Other Banks',
            border: OutlineInputBorder(),
          ),
          items: [
            ...popularBanks,
            'Bank of Baroda',
            'Canara Bank',
            'Union Bank of India',
            'IndusInd Bank',
            'Yes Bank',
            'Federal Bank',
            'IDFC First Bank',
          ].map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedBank = val);
          },
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _processPayment(method: 'NETBANKING', bankName: _selectedBank),
            child: Text('Pay via $_selectedBank', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
