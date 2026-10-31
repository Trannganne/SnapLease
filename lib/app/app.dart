import 'package:flutter/material.dart';
import 'dart:async';
import '../core/storage/token_storage.dart';
import '../features/chat/data/chat_history_store.dart';
import '../features/notification/data/push_service.dart';
import 'router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_cubit.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/rental/bloc/rental_bloc.dart';
import '../features/cart/domain/repositories/cart_repository.dart';
import '../features/cart/data/repositories/dio_cart_repository.dart';
import '../features/cart/bloc/cart_bloc.dart';
import '../features/cart/bloc/cart_event.dart';

class RentCamApp extends StatefulWidget {
  const RentCamApp({super.key});

  @override
  State<RentCamApp> createState() => _RentCamAppState();
}

class _RentCamAppState extends State<RentCamApp> {
  StreamSubscription<String>? _opens;
  @override
  void initState() {
    super.initState();
    ChatHistoryStore.instance.attach();
    _opens = PushService.instance.opens.stream.listen((id) async {
      if (await TokenStorage.getToken() == null) return;
      if (!mounted || PushService.instance.pendingNotificationId != id) return;
      PushService.instance.pendingNotificationId = null;
      AppRouter.router.push('/notification/${Uri.encodeComponent(id)}');
    });
  }

  @override
  void dispose() {
    _opens?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<CartRepository>(
          create: (context) => DioCartRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => RentalBloc()),
          BlocProvider(create: (context) => ThemeCubit()),
          BlocProvider(
            create:
                (context) =>
                    CartBloc(repository: context.read<CartRepository>())
                      ..add(const CartStarted()),
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp.router(
              title: 'RentCam',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              routerConfig: AppRouter.router,
              debugShowCheckedModeBanner: false,
            );
          },
        ),
      ),
    );
  }
}
