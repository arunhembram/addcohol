import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ZoneQrPdfService {
  ZoneQrPdfService._();

  /// Generates a multi-page A4 PDF containing one printable QR sheet per shop in the zone
  static Future<void> generateAndPrintZoneQrs({
    required Zone zone,
    required List<Shop> shops,
  }) async {
    final doc = pw.Document();

    for (final shop in shops) {
      final qrPayload = CanonicalZones.getShopDistributionQrPayload(shop);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 2),
                borderRadius: pw.BorderRadius.circular(16),
              ),
              padding: const pw.EdgeInsets.all(28),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // 1. Zone & Platform Header
                  pw.Column(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blueGrey50,
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(color: PdfColors.blueGrey200),
                        ),
                        child: pw.Text(
                          'ZONE: ${zone.name.toUpperCase()}',
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey800,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 14),
                      pw.Divider(thickness: 1.5, color: PdfColors.grey300),
                    ],
                  ),

                  // 2. Shop & Owner Identification
                  pw.Column(
                    children: [
                      pw.Text(
                        shop.shopName.toUpperCase(),
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      if (shop.ownerName != null && shop.ownerName!.isNotEmpty)
                        pw.Text(
                          'OWNER: ${shop.ownerName!.toUpperCase()}',
                          style: pw.TextStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                        ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          if (shop.shopCode != null)
                            pw.Text(
                              'ID: ${shop.shopCode}   |   ',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey700,
                              ),
                            ),
                          pw.Text(
                            'PHONE: ${shop.phoneNumber ?? "N/A"}',
                            style: pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                      if (shop.address.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          shop.address,
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(
                            fontSize: 11,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // 3. High-Resolution Vector QR Code for Xeroxing/Scanning
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColors.grey800, width: 2),
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: qrPayload,
                      width: 200,
                      height: 200,
                    ),
                  ),

                  // 4. Footer Instructions
                  pw.Column(
                    children: [
                      pw.Divider(thickness: 1.5, color: PdfColors.grey300),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'OFFICIAL MERCHANT DISTRIBUTION QR CODE',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Please display this sheet on your counter or scanner stand for delivery handovers & audits.',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: '${zone.name}_QR_Scanners.pdf',
    );
  }
}
