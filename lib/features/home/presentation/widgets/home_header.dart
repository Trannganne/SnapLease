import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../cart/bloc/cart_bloc.dart';
import '../../../cart/bloc/cart_state.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.92)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.asset('assets/images/logo.png', height: 32),
        ),
        Row(
          children: [
            BlocBuilder<CartBloc, CartState>(
              builder: (context, cartState) {
                final count = cartState.totalLinesCount;
                return GestureDetector(
                  onTap: () {
                    context.push(AppRouter.cart);
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.shopping_bag,
                        size: 28,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      if (count > 0)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                            child: AppText(
                              '$count',
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            UserAvatar(
              displayName: 'Tuan',
              radius: 16,
              onTap: () {
                // TODO: go to profile
              },
            ),
          ],
        ),
      ],
    );
  }
}
