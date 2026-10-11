import 'package:flutter/material.dart';
import 'router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_cubit.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/rental/bloc/rental_bloc.dart';

class RentCamApp extends StatelessWidget {
  const RentCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => RentalBloc()),
        BlocProvider(create: (context) => ThemeCubit()),
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
    );
  }
}
