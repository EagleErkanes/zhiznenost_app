import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../auth/login_screen.dart';
import 'client_detail_screen.dart';

class CoachDashboardScreen extends StatefulWidget {
  const CoachDashboardScreen({super.key});

  @override
  State<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
}

class _CoachDashboardScreenState extends State<CoachDashboardScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  int _mainTab = 0; // 0: Клиенти, 1: Треньори
  int _clientFilterTab = 0; // 0: Моите, 1: Всички

  String _coachName = '';

  List<UserProfile> _allClients = [];
  List<UserProfile> _filteredClients = [];
  List<UserProfile> _allCoaches = [];

  Map<String, Map<String, dynamic>> _visitsSummary = {};

  Map<String, String> _quote = {
    'text':
    'Постоянството побеждава таланта, когато талантът не работи здраво!',
    'author': 'Алекс - Жизненост',
  };

  bool _isLoading = true;
  bool _hasNetworkError = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasNetworkError = false;
      });
    }

    try {
      final currentUserId =
          Supabase.instance.client.auth.currentUser?.id;

      String coachName = _coachName;

      if (currentUserId != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('full_name')
            .eq('id', currentUserId)
            .maybeSingle();

        if (profile != null && profile['full_name'] != null) {
          coachName = profile['full_name'].toString().trim();
        }
      }

      final quoteData = await _dbService.getMotivationalQuote();
      final clientsData = await _dbService.getAllClients();
      final coachesData = await _dbService.getAllCoaches();
      final summaryData =
      await _dbService.getClientsVisitsSummary();

      if (!mounted) return;

      final currentUser =
          Supabase.instance.client.auth.currentUser?.id;

      final query =
      _searchController.text.trim().toLowerCase();

      final filtered = clientsData.where((client) {
        if (_clientFilterTab == 0 &&
            client.coachId != currentUser) {
          return false;
        }

        if (query.isEmpty) {
          return true;
        }

        final name = client.fullName.toLowerCase();
        final email = client.email.toLowerCase();

        return name.contains(query) ||
            email.contains(query);
      }).toList();

      setState(() {
        _coachName = coachName;
        _quote = quoteData;
        _allClients = clientsData;
        _allCoaches = coachesData;
        _visitsSummary = summaryData;
        _filteredClients = filtered;
        _isLoading = false;
        _hasNetworkError = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasNetworkError = true;
      });
    }
  }

  void _applyFilters() {
    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id;

    final query =
    _searchController.text.trim().toLowerCase();

    final filtered = _allClients.where((client) {
// "Моите клиенти"
      if (_clientFilterTab == 0 &&
          client.coachId != currentUserId) {
        return false;
      }

// Няма търсене
      if (query.isEmpty) {
        return true;
      }

      final name = client.fullName.toLowerCase();
      final email = client.email.toLowerCase();

      return name.contains(query) ||
          email.contains(query);
    }).toList();

    if (!mounted) return;

    setState(() {
      _filteredClients = filtered;
    });
  }

  void _changeClientFilterTab(int tab) {
    if (_clientFilterTab == tab) return;

    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id;

    final query =
    _searchController.text.trim().toLowerCase();

    final filtered = _allClients.where((client) {
      if (tab == 0 && client.coachId != currentUserId) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final name = client.fullName.toLowerCase();
      final email = client.email.toLowerCase();

      return name.contains(query) ||
          email.contains(query);
    }).toList();

    setState(() {
      _clientFilterTab = tab;
      _filteredClients = filtered;
    });
  }

  int _getClientsCountForCoach(String coachId) {
    return _allClients
        .where((client) => client.coachId == coachId)
        .length;
  }

  bool _isClientInactive(DateTime? lastActivity) {
    if (lastActivity == null) return true;

    final diff =
        DateTime
            .now()
            .difference(lastActivity)
            .inDays;

    return diff >= 7;
  }

  void _clearSearch() {
    _searchController.clear();

    FocusScope.of(context).unfocus();

    _applyFilters();
  }

  void _showEditQuoteDialog() {
    final formKey = GlobalKey<FormState>();

    final quoteTextController =
    TextEditingController(text: _quote['text']);

    final authorController =
    TextEditingController(text: _quote['author']);

    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bottomInset =
                MediaQuery
                    .of(context)
                    .viewInsets
                    .bottom;

            return Dialog(
              backgroundColor: AppColors.cardDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: AnimatedPadding(
                padding: EdgeInsets.only(
                  bottom: bottomInset > 0 ? 10 : 0,
                ),
                duration:
                const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Редакция на мотивация',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: quoteTextController,
                          maxLines: 3,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                          textInputAction:
                          TextInputAction.next,
                          decoration:
                          const InputDecoration(
                            labelText: 'Цитат на деня',
                            hintText:
                            'Въведете мотивиращо послание...',
                          ),
                          validator: (value) {
                            if (value == null ||
                                value
                                    .trim()
                                    .isEmpty) {
                              return 'Полето с цитата не може да бъде празно';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        TextFormField(
                          controller: authorController,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                          textInputAction:
                          TextInputAction.done,
                          onEditingComplete: () {
                            FocusScope.of(context).unfocus();
                          },
                          decoration:
                          const InputDecoration(
                            labelText: 'Автор / Подпис',
                            hintText:
                            'Напр. Алекс - Жизненост',
                          ),
                          validator: (value) {
                            if (value == null ||
                                value
                                    .trim()
                                    .isEmpty) {
                              return 'Полето за автор не може да бъде празно';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () {
                                FocusScope.of(context)
                                    .unfocus();

                                Navigator.pop(
                                    dialogContext);
                              },
                              child: const Text(
                                'Отказ',
                                style: TextStyle(
                                  color: AppColors
                                      .textSecondary,
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            ElevatedButton(
                              style:
                              ElevatedButton.styleFrom(
                                minimumSize:
                                const Size(100, 44),
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                FocusScope.of(
                                    context)
                                    .unfocus();

                                if (!formKey
                                    .currentState!
                                    .validate()) {
                                  return;
                                }

                                setDialogState(() {
                                  isSaving = true;
                                });

                                final rootNavigator =
                                Navigator.of(
                                    dialogContext);

                                final rootScaffold =
                                ScaffoldMessenger.of(
                                    this.context);

                                try {
                                  await _dbService
                                      .updateMotivationalQuote(
                                    quoteTextController
                                        .text
                                        .trim(),
                                    authorController.text
                                        .trim(),
                                  );

                                  rootNavigator.pop();

                                  await _loadDashboardData();

                                  rootScaffold.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Цитатът беше успешно обновен за всички клиенти!',
                                      ),
                                      backgroundColor:
                                      AppColors
                                          .primaryGreen,
                                      behavior:
                                      SnackBarBehavior
                                          .floating,
                                    ),
                                  );
                                } catch (e) {
                                  setDialogState(() {
                                    isSaving = false;
                                  });

                                  final errStr =
                                  e.toString()
                                      .toLowerCase();

                                  String displayMsg =
                                      'Възникна грешка при запазване.';

                                  if (errStr.contains(
                                      'socketexception') ||
                                      errStr.contains(
                                          'failed host lookup') ||
                                      errStr.contains(
                                          'clientexception') ||
                                      errStr.contains(
                                          'os error') ||
                                      errStr.contains(
                                          'network')) {
                                    displayMsg =
                                    'Няма връзка с интернет. Проверете мрежата си и опитайте отново.';
                                  }

                                  rootScaffold
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        displayMsg,
                                        style:
                                        const TextStyle(
                                          fontWeight:
                                          FontWeight
                                              .bold,
                                        ),
                                      ),
                                      backgroundColor:
                                      AppColors
                                          .errorRed,
                                      behavior:
                                      SnackBarBehavior
                                          .floating,
                                      duration:
                                      const Duration(
                                        seconds: 4,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: isSaving
                                  ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                                  : const Text('Запази'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSignOut() async {
    final navigator = Navigator.of(context);

    try {
      await _authService.signOut();
    } catch (_) {}

    if (!mounted) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 56,
        titleSpacing: 18,

        title: Text(
          _coachName.isNotEmpty
              ? 'Здравей, $_coachName 👋'
              : 'Треньорски панел',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),

        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Презареди',
            onPressed: _loadDashboardData,
          ),

          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: _handleSignOut,
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryGreen,
        ),
      )
          : _hasNetworkError && _allClients.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: AppColors.errorRed,
                size: 48,
              ),

              const SizedBox(height: 12),

              const Text(
                'Няма връзка с интернет.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Моля, проверете мрежата си и опитайте отново.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 18),

              ElevatedButton.icon(
                style:
                ElevatedButton.styleFrom(
                  minimumSize:
                  const Size(140, 44),
                ),
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.black,
                ),
                label:
                const Text('Опитай отново'),
                onPressed:
                _loadDashboardData,
              ),
            ],
          ),
        ),
      )
          : SafeArea(
        bottom: true,
        child: CustomScrollView(
          physics:
          const BouncingScrollPhysics(
            parent:
            AlwaysScrollableScrollPhysics(),
          ),
          keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior
              .onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                child: Column(
                  children: [
// =====================================================
// 1. БРАНДИРАН БАНЕР
// =====================================================

                    Container(
                      margin:
                      const EdgeInsets.only(
                        bottom: 16,
                      ),
                      padding:
                      const EdgeInsets
                          .symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration:
                      BoxDecoration(
                        color:
                        AppColors.cardDark,
                        borderRadius:
                        BorderRadius.circular(
                            20),
                        border: Border.all(
                          color: const Color(
                              0x5576C043),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius:
                            BorderRadius
                                .circular(16),
                            child: SizedBox(
                              width: 64,
                              height: 64,
                              child: Image.asset(
                                'assets/images/logo_icon.jpg',
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) =>
                                const Icon(
                                  Icons
                                      .fitness_center,
                                  color: AppColors
                                      .primaryGreen,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 14),

                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                              mainAxisSize:
                              MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'ЖИЗНЕНОСТ',
                                      style:
                                      TextStyle(
                                        fontSize: 21,
                                        fontWeight:
                                        FontWeight
                                            .w900,
                                        fontStyle:
                                        FontStyle
                                            .italic,
                                        letterSpacing:
                                        1.4,
                                        color: Colors
                                            .white,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '®',
                                      style:
                                      TextStyle(
                                        fontSize: 12,
                                        fontWeight:
                                        FontWeight
                                            .bold,
                                        color: AppColors
                                            .primaryGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'ЦЕНТЪР ЗА ТРЕНИРОВКИ И ВЪЗСТАНОВЯВАНЕ',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight:
                                    FontWeight
                                        .w700,
                                    letterSpacing:
                                    0.7,
                                    color: AppColors
                                        .primaryGreen,
                                  ),
                                  overflow:
                                  TextOverflow
                                      .ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

// =====================================================
// 2. МОТИВАЦИОНЕН БЛОК
// =====================================================

                    Container(
                      padding:
                      const EdgeInsets.all(
                        16,
                      ),
                      decoration:
                      BoxDecoration(
                        color:
                        AppColors.cardDark,
                        borderRadius:
                        BorderRadius.circular(
                            16),
                        border: Border.all(
                          color: const Color(
                              0x4D76C043),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                            children: [
                              const Text(
                                'АКТИВЕН ЦИТАТ ЗА КЛИЕНТИТЕ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                  color: AppColors
                                      .primaryGreen,
                                  letterSpacing:
                                  1.1,
                                ),
                              ),

                              IconButton(
                                icon:
                                const Icon(
                                  Icons.edit,
                                  color: AppColors
                                      .primaryGreen,
                                  size: 18,
                                ),
                                onPressed:
                                _showEditQuoteDialog,
                                padding:
                                EdgeInsets.zero,
                                constraints:
                                const BoxConstraints(),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          Text(
                            '„${_quote['text']}“',
                            style:
                            const TextStyle(
                              fontSize: 14,
                              fontStyle:
                              FontStyle.italic,
                              color: AppColors
                                  .textPrimary,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Align(
                            alignment:
                            Alignment.centerRight,
                            child: Text(
                              '- ${_quote['author']}',
                              style:
                              const TextStyle(
                                fontSize: 12,
                                color: AppColors
                                    .textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

// =====================================================
// 3. ГЛАВНИ ТАБОВЕ
// =====================================================

                    Container(
                      decoration:
                      BoxDecoration(
                        color:
                        AppColors.cardDark,
                        borderRadius:
                        BorderRadius.circular(
                            12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child:
                            GestureDetector(
                              onTap: () {
                                if (_mainTab !=
                                    0) {
                                  setState(() {
                                    _mainTab = 0;
                                  });
                                }
                              },
                              child: Container(
                                padding:
                                const EdgeInsets
                                    .symmetric(
                                  vertical: 12,
                                ),
                                decoration:
                                BoxDecoration(
                                  color: _mainTab ==
                                      0
                                      ? AppColors
                                      .primaryGreen
                                      : Colors
                                      .transparent,
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                      12),
                                ),
                                child: Text(
                                  'Клиенти (${_allClients.length})',
                                  textAlign:
                                  TextAlign
                                      .center,
                                  style:
                                  TextStyle(
                                    color: _mainTab ==
                                        0
                                        ? Colors.black
                                        : AppColors
                                        .textPrimary,
                                    fontWeight:
                                    FontWeight
                                        .bold,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          Expanded(
                            child:
                            GestureDetector(
                              onTap: () {
                                if (_mainTab !=
                                    1) {
                                  setState(() {
                                    _mainTab = 1;
                                  });
                                }
                              },
                              child: Container(
                                padding:
                                const EdgeInsets
                                    .symmetric(
                                  vertical: 12,
                                ),
                                decoration:
                                BoxDecoration(
                                  color: _mainTab ==
                                      1
                                      ? AppColors
                                      .primaryGreen
                                      : Colors
                                      .transparent,
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                      12),
                                ),
                                child: Text(
                                  'Треньори (${_allCoaches.length})',
                                  textAlign:
                                  TextAlign
                                      .center,
                                  style:
                                  TextStyle(
                                    color: _mainTab ==
                                        1
                                        ? Colors.black
                                        : AppColors
                                        .textPrimary,
                                    fontWeight:
                                    FontWeight
                                        .bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

// =====================================================
// 4. CLIENT FILTERS + SEARCH
// =====================================================

                    if (_mainTab == 0) ...[
                      Container(
                        height: 40,
                        decoration:
                        BoxDecoration(
                          color: AppColors
                              .cardDark,
                          borderRadius:
                          BorderRadius.circular(
                              10),
                          border: Border.all(
                            color:
                            Colors.white10,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                    9),
                                onTap: () =>
                                    _changeClientFilterTab(
                                        0),
                                child: Container(
                                  alignment:
                                  Alignment
                                      .center,
                                  decoration:
                                  BoxDecoration(
                                    color:
                                    _clientFilterTab ==
                                        0
                                        ? AppColors
                                        .primaryGreen
                                        : Colors
                                        .transparent,
                                    borderRadius:
                                    BorderRadius
                                        .circular(
                                        9),
                                  ),
                                  child: Text(
                                    'Моите клиенти',
                                    style:
                                    TextStyle(
                                      color: _clientFilterTab ==
                                          0
                                          ? Colors
                                          .black
                                          : AppColors
                                          .textPrimary,
                                      fontWeight:
                                      FontWeight
                                          .bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            Expanded(
                              child: InkWell(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                    9),
                                onTap: () =>
                                    _changeClientFilterTab(
                                        1),
                                child: Container(
                                  alignment:
                                  Alignment
                                      .center,
                                  decoration:
                                  BoxDecoration(
                                    color:
                                    _clientFilterTab ==
                                        1
                                        ? AppColors
                                        .primaryGreen
                                        : Colors
                                        .transparent,
                                    borderRadius:
                                    BorderRadius
                                        .circular(
                                        9),
                                  ),
                                  child: Text(
                                    'Всички в залата',
                                    style:
                                    TextStyle(
                                      color: _clientFilterTab == 1
                                          ? Colors
                                          .black
                                          : AppColors
                                          .textPrimary,
                                      fontWeight:
                                      FontWeight
                                          .bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller:
                        _searchController,

                        onChanged: (_) {
                          _applyFilters();
                        },

                        style:
                        const TextStyle(
                          color: AppColors
                              .textPrimary,
                        ),

                        textInputAction:
                        TextInputAction.done,

                        onEditingComplete: () {
                          FocusScope.of(context)
                              .unfocus();
                        },

                        decoration:
                        InputDecoration(
                          hintText:
                          'Търси клиент по име или имейл...',

                          prefixIcon:
                          const Icon(
                            Icons.search,
                            color: AppColors
                                .textSecondary,
                          ),

                          suffixIcon:
                          _searchController
                              .text
                              .isNotEmpty
                              ? IconButton(
                            icon:
                            const Icon(
                              Icons.clear,
                              color: AppColors
                                  .textSecondary,
                            ),
                            onPressed:
                            _clearSearch,
                          )
                              : null,
                        ),
                      ),

                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
            ),

// =============================================================
// 5. СПИСЪК
// =============================================================

            SliverPadding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 4,
              ),
              sliver:
              _buildListContent(
                currentUserId,
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListContent(String? currentUserId) {
// ===============================================================
// CLIENTS
// ===============================================================

    if (_mainTab == 0) {
      if (_filteredClients.isEmpty) {
        return SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Text(
              _clientFilterTab == 0
                  ? 'Нямате прикрепени клиенти все още.\nИзберете „Всички в залата“, за да прикрепите.'
                  : 'Няма намерени клиенти.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        );
      }

      return SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final client =
            _filteredClients[index];

            final isMyClient =
                client.coachId == currentUserId;

            final clientSummary =
            _visitsSummary[client.id];

            final DateTime? lastActivity =
            clientSummary?['last_visit'];

            final int monthVisits =
                clientSummary?['month_visits'] ?? 0;

            final isInactive =
            _isClientInactive(lastActivity);

            return Card(
              color: AppColors.cardDark,
              margin: const EdgeInsets.only(
                bottom: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(12),
                side: BorderSide(
                  color: isInactive
                      ? AppColors.errorRed
                      .withAlpha(90)
                      : Colors.transparent,
                  width:
                  isInactive ? 1.2 : 0,
                ),
              ),
              child: InkWell(
                borderRadius:
                BorderRadius.circular(12),
                onTap: () async {
                  FocusScope.of(context)
                      .unfocus();

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ClientDetailScreen(
                            client: client,
                          ),
                    ),
                  );

                  if (mounted) {
                    await _loadDashboardData();
                  }
                },
                child: Padding(
                  padding:
                  const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                            const Color(
                                0x3376C043),
                            child: Text(
                              client.fullName
                                  .isNotEmpty
                                  ? client.fullName
                                  .substring(
                                  0, 1)
                                  .toUpperCase()
                                  : 'К',
                              style:
                              const TextStyle(
                                color: AppColors
                                    .primaryGreen,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        client.fullName,
                                        style:
                                        const TextStyle(
                                          color: AppColors
                                              .textPrimary,
                                          fontWeight:
                                          FontWeight
                                              .bold,
                                          fontSize: 15,
                                        ),
                                        maxLines: 1,
                                        overflow:
                                        TextOverflow
                                            .ellipsis,
                                      ),
                                    ),

                                    if (isInactive) ...[
                                      const SizedBox(
                                          width: 8),

                                      Container(
                                        padding:
                                        const EdgeInsets
                                            .symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration:
                                        BoxDecoration(
                                          color: AppColors
                                              .errorRed
                                              .withAlpha(
                                              40),
                                          borderRadius:
                                          BorderRadius
                                              .circular(
                                              6),
                                        ),
                                        child:
                                        const Text(
                                          'НЕАКТИВЕН (7+ дни)',
                                          style:
                                          TextStyle(
                                            color: AppColors
                                                .errorRed,
                                            fontSize: 10,
                                            fontWeight:
                                            FontWeight
                                                .w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                const SizedBox(height: 2),

                                Text(
                                  client.email,
                                  style:
                                  const TextStyle(
                                    color: AppColors
                                        .textSecondary,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow:
                                  TextOverflow
                                      .ellipsis,
                                ),
                              ],
                            ),
                          ),

                          if (!isMyClient &&
                              currentUserId != null)
                            TextButton.icon(
                              icon: const Icon(
                                Icons.person_add,
                                size: 16,
                                color: AppColors
                                    .primaryGreen,
                              ),
                              label: const Text(
                                'Прикрепи',
                                style: TextStyle(
                                  color: AppColors
                                      .primaryGreen,
                                  fontSize: 12,
                                ),
                              ),
                              onPressed: () async {
                                FocusScope.of(
                                    context)
                                    .unfocus();

                                await _dbService
                                    .assignClientToCoach(
                                  client.id,
                                  currentUserId,
                                );

                                if (mounted) {
                                  await _loadDashboardData();
                                }
                              },
                            )
                          else
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors
                                  .textSecondary,
                            ),
                        ],
                      ),

                      const Divider(
                        height: 18,
                        color: Colors.white10,
                      ),

                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Посещения: $monthVisits',
                              style:
                              const TextStyle(
                                color: AppColors
                                    .textPrimary,
                                fontSize: 12,
                                fontWeight:
                                FontWeight.w600,
                              ),
                              overflow:
                              TextOverflow.ellipsis,
                            ),
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: Text(
                              lastActivity != null
                                  ? 'Активност: ${lastActivity
                                  .day}.${lastActivity.month}.${lastActivity
                                  .year}'
                                  : 'Няма активност',
                              textAlign:
                              TextAlign.end,
                              style: TextStyle(
                                color: isInactive
                                    ? AppColors
                                    .errorRed
                                    : AppColors
                                    .textSecondary,
                                fontSize: 11,
                                fontWeight: isInactive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              overflow:
                              TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount:
          _filteredClients.length,
        ),
      );
    }

// ===============================================================
// COACHES
// ===============================================================

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final coach =
          _allCoaches[index];

          final count =
          _getClientsCountForCoach(
              coach.id);

          final isMe =
              coach.id == currentUserId;

          return Card(
            color: AppColors.cardDark,
            margin:
            const EdgeInsets.only(
              bottom: 10,
            ),
            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(12),
              side: BorderSide(
                color: isMe
                    ? const Color(0x8076C043)
                    : Colors.transparent,
              ),
            ),
            child: ListTile(
              contentPadding:
              const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),

              leading: CircleAvatar(
                backgroundColor: isMe
                    ? AppColors.primaryGreen
                    : Colors.white12,
                child: Icon(
                  Icons.fitness_center,
                  color: isMe
                      ? Colors.black
                      : AppColors.textPrimary,
                  size: 18,
                ),
              ),

              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      coach.fullName,
                      style:
                      const TextStyle(
                        color: AppColors
                            .textPrimary,
                        fontWeight:
                        FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                    ),
                  ),

                  if (isMe) ...[
                    const SizedBox(width: 8),

                    Container(
                      padding:
                      const EdgeInsets
                          .symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration:
                      BoxDecoration(
                        color: const Color(
                            0x3376C043),
                        borderRadius:
                        BorderRadius.circular(
                            6),
                      ),
                      child: const Text(
                        'Ти',
                        style:
                        TextStyle(
                          color: AppColors
                              .primaryGreen,
                          fontSize: 10,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              subtitle: Text(
                coach.email,
                style:
                const TextStyle(
                  color: AppColors
                      .textSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow:
                TextOverflow.ellipsis,
              ),

              trailing: Container(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration:
                BoxDecoration(
                  color: AppColors
                      .backgroundDark,
                  borderRadius:
                  BorderRadius.circular(
                      20),
                ),
                child: Text(
                  '$count клиенти',
                  style:
                  const TextStyle(
                    color: AppColors
                        .primaryGreen,
                    fontWeight:
                     FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
        childCount: _allCoaches.length,
      ),
    );
  }
}

