import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/logger.dart';
import '../../../l10n/app_localizations.dart';
import '../data/totp_service.dart';
import 'qr_scan.dart';

class TotpEditResult {
  final TotpConfig config;
  TotpEditResult(this.config);
}

Future<TotpEditResult?> showTotpEditSheet(
  BuildContext context, {
  TotpConfig? initial,
}) {
  return showModalBottomSheet<TotpEditResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TotpEditSheet(initial: initial),
  );
}

class _TotpEditSheet extends StatefulWidget {
  final TotpConfig? initial;
  const _TotpEditSheet({this.initial});

  @override
  State<_TotpEditSheet> createState() => _TotpEditSheetState();
}

class _TotpEditSheetState extends State<_TotpEditSheet> {
  final _uriCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  int _period = 30;
  int _digits = 6;
  String _algorithm = 'SHA1';
  bool _isUriMode = true;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _secretCtrl.text = widget.initial!.secret;
      _period = widget.initial!.period;
      _digits = widget.initial!.digits;
      _algorithm = widget.initial!.algorithm;
      _isUriMode = false;
    }
  }

  @override
  void dispose() {
    _uriCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  void _parseUri() {
    final totpService = TotpService();
    final config = totpService.parseUri(_uriCtrl.text);
    if (config != null) {
      setState(() {
        _secretCtrl.text = config.secret;
        _period = config.period;
        _digits = config.digits;
        _algorithm = config.algorithm;
        _isUriMode = false;
      });
    } else {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.totpInvalidUri)),
      );
    }
  }

  Future<void> _scanQrCode() async {
    try {
      final scanned = await openQrScanner(context);
      if (scanned == null) return;
      _uriCtrl.text = scanned;
      _parseUri();
    } catch (e) {
      log.e('QR scan failed', error: e);
    }
  }

  void _submit() {
    final secret = _secretCtrl.text.trim().replaceAll(' ', '');
    if (secret.isEmpty) return;
    Navigator.pop(context, TotpEditResult(TotpConfig(
      secret: secret,
      period: _period,
      digits: _digits,
      algorithm: _algorithm,
    )));

  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.setupTotp, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (_isUriMode) ...[
            if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _scanQrCode,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(l10n.scanQrCode),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _uriCtrl,
              decoration: InputDecoration(
                labelText: l10n.totpUriLabel,
                hintText: 'otpauth://totp/...',
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _parseUri,
                child: Text(l10n.totpParseUri),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _isUriMode = false),
                child: Text(l10n.totpManualConfig),
              ),
            ),
          ] else ...[
            TextField(
              controller: _secretCtrl,
              decoration: InputDecoration(
                labelText: l10n.totpSecretLabel,
                hintText: 'JBSWY3DPEHPK3PXP',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _period,
                    decoration: InputDecoration(
                      labelText: l10n.totpPeriodLabel,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 15, child: Text('15s')),
                      DropdownMenuItem(value: 30, child: Text('30s')),
                      DropdownMenuItem(value: 60, child: Text('60s')),
                    ],
                    onChanged: (v) => setState(() => _period = v ?? 30),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _digits,
                    decoration: InputDecoration(
                      labelText: l10n.totpDigitsLabel,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 6, child: Text('6')),
                      DropdownMenuItem(value: 8, child: Text('8')),
                    ],
                    onChanged: (v) => setState(() => _digits = v ?? 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _algorithm,
              decoration: InputDecoration(
                labelText: l10n.totpAlgorithmLabel,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: [
                DropdownMenuItem(value: 'SHA1', child: Text(l10n.totpAlgoSha1)),
                DropdownMenuItem(value: 'SHA256', child: Text(l10n.totpAlgoSha256)),
                DropdownMenuItem(value: 'SHA512', child: Text(l10n.totpAlgoSha512)),
              ],
              onChanged: (v) => setState(() => _algorithm = v ?? 'SHA1'),
            ),
            const SizedBox(height: 8),
            if (widget.initial == null)
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _isUriMode = true),
                  child: Text(l10n.totpPasteUri),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _secretCtrl.text.trim().isEmpty ? null : _submit,
                    child: Text(l10n.confirm),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
