import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../features/auth/login/presentation/login_page.dart';
import '../../features/auth/register/presentation/register_page.dart';
import '../../features/main/presentation/main_layout.dart';
import '../../features/device_detail/presentation/device_detail_page.dart';
import '../../features/identity_verification/presentation/identity_verification_page.dart';
import '../../features/rental_confirmation/presentation/rental_confirmation_page.dart';
import '../../features/contract/presentation/contract_page.dart';
import '../../features/contract/presentation/contract_preview_page.dart';
import '../../features/contract/presentation/signature_page.dart';
import '../../features/contract/presentation/bloc/contract_signing_cubit.dart';
import '../../features/contract/data/repositories/dio_contract_signing_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/contract/services/contract_pdf_service.dart';
import '../../features/contract/presentation/tracking/contract_tracking_page.dart';
import '../../features/contract/presentation/renewal/contract_renewal_page.dart';
import '../../features/payment/presentation/payment_page.dart';
import '../../features/payment/presentation/payment_success_page.dart';
import '../../features/test_api/presentation/test_api_page.dart';

class AppRouter {
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/';
  static const String testApi = '/test-api';

  static final GoRouter router = GoRouter(
    initialLocation: testApi,
    routes: [
      GoRoute(path: testApi, builder: (context, state) => const TestApiPage()),
      GoRoute(path: login, builder: (context, state) => const LoginPage()),
      GoRoute(
        path: register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: forgotPassword,
        builder:
            (context, state) => const Scaffold(
              body: Center(child: Text('Forgot Password - To be implemented')),
            ),
      ),
      GoRoute(path: home, builder: (context, state) => const MainLayout()),
      GoRoute(
        path: '/device/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? 'default';
          final reviewMode = state.uri.queryParameters['reviewMode'] == 'true';
          return DeviceDetailPage(deviceId: id, reviewMode: reviewMode);
        },
      ),
      GoRoute(
        path: '/identity-verification',
        builder: (context, state) => const IdentityVerificationPage(),
      ),

      GoRoute(
        path: '/rental-confirmation',
        builder: (context, state) => const RentalConfirmationPage(),
      ),
      GoRoute(
        path: '/contract/preview',
        builder: (context, state) {
          final contract = state.extra as ContractModel;
          return ContractPreviewPage(contract: contract);
        },
      ),
      GoRoute(
        path: '/contract/tracking',
        builder: (context, state) {
          final contract = state.extra as ContractModel;
          return ContractTrackingPage(contract: contract);
        },
      ),
      GoRoute(
        path: '/contract/renewal',
        builder: (context, state) {
          final contract = state.extra as ContractModel;
          return ContractRenewalPage(contract: contract);
        },
      ),
      GoRoute(
        path: '/contract/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          String? action;
          if (extra is Map<String, dynamic> && extra.containsKey('action')) {
            action = extra['action'] as String?;
          } else {
            action = state.uri.queryParameters['action'];
          }
          return ContractPage(contractId: id, action: action);
        },
      ),
      GoRoute(
        path: '/signature',
        builder: (context, state) {
          final contract = state.extra as ContractModel;
          return BlocProvider(
            create: (context) => ContractSigningCubit(DioContractSigningRepository()),
            child: SignaturePage(contract: contract),
          );
        },
      ),
      GoRoute(
        path: '/payment',
        builder: (context, state) {
          final contract = state.extra as ContractModel;
          return PaymentPage(contract: contract);
        },
      ),
      GoRoute(
        path: '/payment/success',
        builder: (context, state) {
          final contract = state.extra as ContractModel;
          return PaymentSuccessPage(contract: contract);
        },
      ),
    ],
  );
}
