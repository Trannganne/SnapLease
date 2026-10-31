import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../home/presentation/home_page.dart';
import '../../account/presentation/account_page.dart';
import '../../explore/presentation/explore_page.dart';
import '../../contract/presentation/list/contract_list_page.dart';
import '../../explore/bloc/explore_bloc.dart';
import '../../explore/bloc/explore_event.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../notification/presentation/notification_page.dart';

class MainLayout extends StatefulWidget {
  final int initialIndex;

  const MainLayout({super.key, this.initialIndex = 0});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(MainLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      _currentIndex = widget.initialIndex;
    }
  }

  void _navigateToExplore() {
    setState(() {
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<CatalogRepository>(
          create: (context) => CatalogRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ExploreBloc>(
            create:
                (context) =>
                    ExploreBloc(repository: context.read<CatalogRepository>())
                      ..add(const ExploreCriteriaChanged()),
          ),
        ],
        child: _buildScaffold(),
      ),
    );
  }

  Widget _buildScaffold() {
    return Builder(
      builder: (context) {
        final List<Widget> pages = [
          HomePage(onNavigateToExplore: _navigateToExplore),
          const ExplorePage(),
          const ContractListPage(),
          const NotificationPage(),
          _buildProfilePage(context),
        ];

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: [
              for (var i = 0; i < pages.length; i++)
                TickerMode(enabled: i == _currentIndex, child: pages[i]),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Theme.of(context).colorScheme.surface,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 10,
              ),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Trang chủ',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.explore_outlined),
                  activeIcon: Icon(Icons.explore),
                  label: 'Khám phá',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.description_outlined),
                  activeIcon: Icon(Icons.description),
                  label: 'Hợp đồng',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications_none_outlined),
                  activeIcon: Icon(Icons.notifications),
                  label: 'Thông báo',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Tài khoản',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfilePage(BuildContext context) {
    return const AccountPage();
  }
}
