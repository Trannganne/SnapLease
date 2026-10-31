import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../core/widgets/app_text.dart';
import '../services/contract_pdf_service.dart';
import '../data/repositories/contract_document_repository.dart';
import 'bloc/contract_document_cubit.dart';
import '../../../core/widgets/snap_loading_view.dart';
import '../../../core/widgets/retro_camera_loader.dart';

class ContractPreviewPage extends StatefulWidget {
  final ContractModel contract;
  final ContractDocumentRepository? documentRepository;
  final Future<Uint8List> Function()? pdfLoader;
  final String title;

  const ContractPreviewPage({
    super.key,
    required this.contract,
    this.documentRepository,
    this.pdfLoader,
    this.title = 'Hợp đồng thuê',
  });

  @override
  State<ContractPreviewPage> createState() => _ContractPreviewPageState();
}

class _ContractPreviewPageState extends State<ContractPreviewPage> {
  late ContractDocumentCubit _documents;
  Future<Uint8List>? _pdfFuture;

  @override
  void initState() {
    super.initState();
    _documents = ContractDocumentCubit(
      widget.documentRepository ?? ContractDocumentRepository(),
    );
    _pdfFuture = widget.pdfLoader?.call() ?? _documents.load(widget.contract);
  }

  @override
  void didUpdateWidget(covariant ContractPreviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentRepository != widget.documentRepository) {
      _documents.close();
      _documents = ContractDocumentCubit(
        widget.documentRepository ?? ContractDocumentRepository(),
      );
    }
    if (oldWidget.contract != widget.contract ||
        oldWidget.documentRepository != widget.documentRepository) {
      _pdfFuture = widget.pdfLoader?.call() ?? _documents.load(widget.contract);
    }
  }

  @override
  void dispose() {
    _documents.close();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _pdfFuture = widget.pdfLoader?.call() ?? _documents.load(widget.contract);
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
          widget.title,
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
                if (pdfData != null && mounted) {
                  await Printing.sharePdf(
                    bytes: pdfData,
                    filename: '${widget.contract.contractId}.pdf',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: PdfPreview(
        loadingWidget: const SnapLoadingView(
          message: 'Đang tải tài liệu hợp đồng',
          size: RetroCameraLoader.large,
        ),
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
