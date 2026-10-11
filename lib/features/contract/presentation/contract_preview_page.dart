import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:dio/dio.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/network/api_client.dart';
import '../services/contract_pdf_service.dart';

class ContractPreviewPage extends StatefulWidget {
  final ContractModel contract;

  const ContractPreviewPage({super.key, required this.contract});

  @override
  State<ContractPreviewPage> createState() => _ContractPreviewPageState();
}

class _ContractPreviewPageState extends State<ContractPreviewPage> {
  final ContractPdfService _pdfService = ContractPdfService();
  Future<Uint8List>? _pdfFuture;

  @override
  void initState() {
    super.initState();
    _pdfFuture = _getPdfBytes();
  }

  Future<Uint8List> _getPdfBytes() async {
    final status = widget.contract.status;
    final isSigned = status == 'DA_KY' || 
                     status == 'CHO_BAN_GIAO' || 
                     status == 'DANG_THUE' || 
                     status == 'HOAN_THANH';

    if (isSigned) {
      try {
        final response = await ApiClient.instance.get(
          '/api/hop-dong/${widget.contract.contractId}/tep-pdf',
          options: Options(responseType: ResponseType.bytes),
        );
        if (response.data is Uint8List) {
          return response.data as Uint8List;
        }
        return Uint8List.fromList(response.data as List<int>);
      } catch (e) {
        throw Exception('Không thể tải PDF đã ký. Vui lòng thử lại.');
      }
    }
    
    if (widget.contract.signatureResult?.pdfBytes != null) {
      return widget.contract.signatureResult!.pdfBytes;
    }
    
    return _pdfService.generateContractPdf(widget.contract);
  }

  void _retry() {
    setState(() {
      _pdfFuture = _getPdfBytes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: AppText(
          'Hợp đồng thuê',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.download,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () async {
              try {
                final pdfData = await _pdfFuture;
                if (pdfData != null) {
                  await Printing.sharePdf(
                    bytes: pdfData,
                    filename: '${widget.contract.contractId}.pdf',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => _pdfFuture!,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        onError: (context, error) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                AppText(
                  error.toString().replaceAll('Exception: ', ''),
                  color: Colors.red,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _retry,
                  child: const AppText('Thử lại', color: Colors.white),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
