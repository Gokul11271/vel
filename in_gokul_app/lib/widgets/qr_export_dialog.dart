import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';

/// Modal dialog that generates, displays, and shares an entrance QR code image.
class QrExportDialog extends StatefulWidget {
  final String buildingId;
  final String buildingName;
  final String entranceName;

  const QrExportDialog({
    super.key,
    required this.buildingId,
    required this.buildingName,
    required this.entranceName,
  });

  /// Helper to show this dialog directly.
  static Future<void> show(
    BuildContext context, {
    required String buildingId,
    required String buildingName,
    required String entranceName,
  }) {
    return showDialog(
      context: context,
      builder: (_) => QrExportDialog(
        buildingId: buildingId,
        buildingName: buildingName,
        entranceName: entranceName,
      ),
    );
  }

  @override
  State<QrExportDialog> createState() => _QrExportDialogState();
}

class _QrExportDialogState extends State<QrExportDialog> {
  bool _isSharing = false;

  String get _qrData => '{"building":"${widget.buildingId}"}';

  Future<void> _shareQrCode() async {
    setState(() => _isSharing = true);
    try {
      final painter = QrPainter(
        data: _qrData,
        version: QrVersions.auto,
        gapless: true,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF0F172A),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF0F172A),
        ),
      );

      final picData = await painter.toImageData(600);
      if (picData == null) throw Exception('Failed to render QR image');

      final bytes = picData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${widget.buildingId}_entrance_qr.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '🚪 Entrance QR Code for ${widget.buildingName}\n'
            'Print and place this QR code at the building entrance for AR navigation.',
        subject: '${widget.buildingName} Entrance QR Code',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error sharing QR code: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.creamSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.softBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.qr_code_2_rounded,
                      color: AppColors.primaryBlue, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Entrance QR Code',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.buildingName,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // QR Code Card Container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.creamBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: _qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.primaryBlue,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '🚪 ${widget.entranceName}',
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${widget.buildingId}',
                    style: const TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Explanation note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.softBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.primaryBlue, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Print & place this QR at the building entrance. Visitors scan it to navigate indoors.',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Share / Save Button
            ElevatedButton.icon(
              icon: _isSharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.share_rounded, size: 20),
              label: Text(_isSharing ? 'Preparing QR Image…' : 'Share / Print QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSharing ? null : _shareQrCode,
            ),
          ],
        ),
      ),
    );
  }
}
