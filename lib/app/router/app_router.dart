import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../features/auth/login/presentation/login_page.dart';
import '../../features/auth/register/presentation/register_page.dart';
import '../../features/main/presentation/main_layout.dart';
import '../../features/device_detail/presentation/device_detail_page.dart';
import '../../features/identity_verification/presentation/identity_verification_page.dart';
import '../../features/rental_confirmation/presentation/rental_confirmation_page.dart';
import '../../features/contract/presentation/contract_page.dart';
import '../../features/contract/presentation/settlement/settlement_detail_page.dart';
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
import '../../features/payment/presentation/payment_result_page.dart';
import '../../features/test_api/presentation/test_api_page.dart';
import 'package:flutter/foundation.dart';
import '../../features/notification/domain/models/notification_item_model.dart';
import '../../features/notification/presentation/notification_detail_page.dart';
import '../../features/notification/presentation/notification_preview_page.dart';
import '../../features/review/domain/models/review_target_device.dart';
import '../../features/review/presentation/review_page.dart';
import '../../features/review/presentation/review_preview_page.dart';
import '../../features/cart/presentation/cart_page.dart';
import '../../features/contract/data/repositories/contract_repository.dart';
import '../../core/navigation/app_route_observer.dart';
import '../../features/auth/password_recovery/presentation/password_recovery_page.dart';
import '../../features/chat/presentation/chat_page.dart';

class AppRouter {
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String verifyEmail = '/verify-email';
  static const String home = '/';
  static const String testApi = '/test-api';
  static const String cart = '/cart';
  static const String chat = '/support/chat';

  static final GoRouter router = createRouter();

  static GoRouter createRouter({String initialLocation = testApi}) {
    Object? pendingAuthLink;
    String? pendingAuthPath;
    int authEntry = 0;
    return GoRouter(
      observers: [appRouteObserver],
      initialLocation: initialLocation,
      redirect: (context, state) {
        final uri = state.uri;
        if (uri.scheme == 'rentalcamera' && uri.host == 'auth-link') {
          String? token;
          try {
            final values = Uri.splitQueryString(uri.fragment);
            if (uri.fragment.split('&').length == 1 &&
                values.length == 1 &&
                values.containsKey('token')) {
              token = values['token'];
            }
          } on FormatException {
            /* Invalid links never reach a token-bearing error page. */
          }
          if (token == null ||
              token.isEmpty ||
              token.length > 5000 ||
              uri.query.isNotEmpty ||
              uri.hasPort ||
              uri.userInfo.isNotEmpty) {
            token = null;
          }
          if (uri.path == resetPassword) {
            pendingAuthPath = resetPassword;
            pendingAuthLink =
                token == null ? null : PasswordResetArguments(token);
          } else {
            pendingAuthPath = verifyEmail;
            pendingAuthLink = EmailVerificationArguments.token(
              uri.path == verifyEmail ? token : null,
            );
          }
          // Strip the token before building app navigation/history. No persistent token cache.
          // Replace stale token/form state when another link opens the same screen.
          // Navigation records only a non-secret entry counter.
          return '$pendingAuthPath?entry=${++authEntry}';
        }
        if (uri.path != pendingAuthPath) {
          pendingAuthLink = null;
          pendingAuthPath = null;
        }
        if (uri.scheme == 'rentalcamera' && uri.host == 'payment-result') {
          return Uri(path: '/payment-result', query: uri.query).toString();
        }
        return null;
      },
      routes: [
        GoRoute(
          path: testApi,
          builder: (context, state) => const TestApiPage(),
        ),
        GoRoute(path: login, builder: (context, state) => const LoginPage()),
        GoRoute(
          path: register,
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: forgotPassword,
          builder: (context, state) => const ForgotPasswordPage(),
        ),
        GoRoute(
          path: resetPassword,
          builder:
              (context, state) => ResetPasswordPage(
                resetToken:
                    state.extra is PasswordResetArguments
                        ? (state.extra as PasswordResetArguments).resetToken
                        : pendingAuthLink is PasswordResetArguments
                        ? (pendingAuthLink as PasswordResetArguments).resetToken
                        : null,
              ),
        ),
        GoRoute(
          path: verifyEmail,
          builder: (context, state) {
            final args =
                state.extra is EmailVerificationArguments
                    ? state.extra as EmailVerificationArguments
                    : pendingAuthLink is EmailVerificationArguments
                    ? pendingAuthLink as EmailVerificationArguments
                    : null;
            return ResetPasswordPage(
              resetToken: args?.token,
              emailVerification: true,
              requestVerification: args?.requestLink ?? false,
            );
          },
        ),
        GoRoute(
          path: home,
          builder: (context, state) {
            final tabStr = state.uri.queryParameters['tab'];
            final initialIndex =
                (tabStr == 'contracts' || tabStr == '2')
                    ? 2
                    : (tabStr == 'explore' || tabStr == '1')
                    ? 1
                    : (int.tryParse(tabStr ?? '') ?? 0);
            return MainLayout(initialIndex: initialIndex);
          },
        ),
        GoRoute(path: cart, builder: (context, state) => const CartPage()),
        GoRoute(path: chat, builder: (context, state) => const ChatPage()),
        GoRoute(
          path: '/contracts',
          redirect: (context, state) => '/?tab=contracts',
        ),
        GoRoute(
          path: '/device/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? 'default';
            final reviewMode =
                state.uri.queryParameters['reviewMode'] == 'true';
            return DeviceDetailPage(deviceId: id, reviewMode: reviewMode);
          },
        ),
        GoRoute(
          path: '/identity-verification',
          builder:
              (context, state) => IdentityVerificationPage(
                fromAccount:
                    state.extra is Map &&
                    (state.extra as Map)['fromAccount'] == true,
              ),
        ),

        GoRoute(
          path: '/rental-confirmation',
          builder: (context, state) => const RentalConfirmationPage(),
        ),
        GoRoute(
          path: '/contract/preview',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is ContractModel) {
              return ContractPreviewPage(contract: extra);
            }
            final id = state.uri.queryParameters['contractId'];
            if (id != null && id.isNotEmpty) {
              return ContractPage(contractId: id);
            }
            return const MainLayout(initialIndex: 2);
          },
        ),
        GoRoute(
          path: '/contract/tracking',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is ContractModel) {
              return ContractTrackingPage(contract: extra);
            }
            final id = state.uri.queryParameters['contractId'];
            if (id != null && id.isNotEmpty) {
              return ContractPage(contractId: id);
            }
            return const MainLayout(initialIndex: 2);
          },
        ),
        GoRoute(
          path: '/contract/renewal',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is ContractModel) {
              return ContractRenewalPage(contract: extra);
            }
            final id = state.uri.queryParameters['contractId'];
            if (id != null && id.isNotEmpty) {
              return ContractPage(
                contractId: id,
                action: 'renewal',
                appendixId: state.uri.queryParameters['appendixId'],
              );
            }
            return const MainLayout(initialIndex: 2);
          },
        ),
        GoRoute(
          path: '/contract/appendix/:id/pdf',
          builder: (context, state) {
            final contract = state.extra;
            if (contract is! ContractModel) {
              return const MainLayout(initialIndex: 2);
            }
            return ContractPreviewPage(
              contract: contract,
              title: 'Phụ lục gia hạn',
              pdfLoader:
                  () => ContractRepository().loadAppendixPdf(
                    state.pathParameters['id']!,
                  ),
            );
          },
        ),
        GoRoute(
          path: '/contract/:id/settlement',
          builder:
              (context, state) =>
                  SettlementDetailPage(contractId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/contract/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final extra = state.extra;
            String? action;
            if (extra is Map<String, dynamic> && extra.containsKey('action')) {
              action = extra['action'] as String?;
            } else {
              action = state.uri.queryParameters['action'];
            }
            return ContractPage(
              contractId: id,
              action: action,
              appendixId: state.uri.queryParameters['appendixId'],
            );
          },
        ),
        GoRoute(
          path: '/signature',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is ContractModel) {
              return BlocProvider(
                create:
                    (context) =>
                        ContractSigningCubit(DioContractSigningRepository()),
                child: SignaturePage(contract: extra),
              );
            }
            final id = state.uri.queryParameters['contractId'];
            if (id != null && id.isNotEmpty) {
              return ContractPage(contractId: id);
            }
            return const MainLayout(initialIndex: 2);
          },
        ),
        GoRoute(
          path: '/payment',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is ContractModel) {
              return PaymentPage(contract: extra);
            }
            final id = state.uri.queryParameters['contractId'];
            if (id != null && id.isNotEmpty) {
              return ContractPage(contractId: id);
            }
            return const MainLayout(initialIndex: 2);
          },
        ),
        GoRoute(
          path: '/payment/success',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is ContractModel) {
              return PaymentSuccessPage(contract: extra);
            }
            final id = state.uri.queryParameters['contractId'];
            if (id != null && id.isNotEmpty) {
              return ContractPage(contractId: id);
            }
            return const MainLayout(initialIndex: 2);
          },
        ),
        GoRoute(
          path: '/payment-result',
          builder: (context, state) {
            final paymentId =
                state.uri.queryParameters['maThanhToan'] ??
                state.uri.queryParameters['paymentId'] ??
                '';
            return PaymentResultPage(paymentId: paymentId);
          },
        ),
        GoRoute(
          path: '/notification/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final extra = state.extra;
            NotificationItemModel? item;
            if (extra is NotificationItemModel && extra.id == id) {
              item = extra;
            }
            return NotificationDetailPage(
              notificationId: id,
              initialItem: item,
            );
          },
        ),
        GoRoute(
          path: '/notification-preview',
          builder: (context, state) {
            if (kReleaseMode) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Trang này không khả dụng trên môi trường Release.',
                  ),
                ),
              );
            }
            return const NotificationPreviewPage();
          },
        ),
        GoRoute(
          path: '/review/:contractDetailId',
          builder: (context, state) {
            final detailId = state.pathParameters['contractDetailId'] ?? '';
            final extra = state.extra;
            ReviewTargetDevice? targetDevice;
            if (extra is ReviewTargetDevice && extra.detailId == detailId) {
              targetDevice = extra;
            }
            return ReviewPage(detailId: detailId, device: targetDevice);
          },
        ),
        GoRoute(
          path: '/review-preview',
          builder: (context, state) {
            if (!kDebugMode) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Trang này chỉ khả dụng trong chế độ gỡ lỗi (Debug mode).',
                  ),
                ),
              );
            }
            return const ReviewPreviewPage();
          },
        ),
      ],
    );
  }
}
