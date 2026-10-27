// WiSplit Client Library Barrel File

// Models
export 'data/models/expense_models.dart';
export 'data/models/settlement_model.dart';
export 'data/models/personal_ledger_model.dart';
export 'data/models/group_model.dart';
export 'data/models/user_session_model.dart';

// Core Network & Storage
export 'core/network/api_client.dart';
export 'core/network/network_info.dart';
export 'core/database/local_database.dart';
export 'core/database/sync_queue_service.dart';

// Services
export 'data/services/expense_api_service.dart';
export 'data/services/personal_ledger_service.dart';
export 'data/services/auth_service.dart';

// Repositories
export 'data/repositories/expense_repository.dart';
export 'data/repositories/personal_ledger_repository.dart';
export 'data/repositories/group_repository.dart';

// Theme
export 'core/theme/app_colors.dart';
export 'core/theme/app_typography.dart';
export 'core/theme/app_theme.dart';

// Screens & Widgets
export 'presentation/screens/home_screen.dart';
export 'presentation/screens/dashboard_screen.dart';
export 'presentation/screens/groups_screen.dart';
export 'presentation/screens/group_detail_screen.dart';
export 'presentation/screens/balances_screen.dart';
export 'presentation/screens/activity_screen.dart';
export 'presentation/screens/friend_profile_screen.dart';
export 'presentation/screens/expense_details_screen.dart';
export 'presentation/screens/auth_screen.dart';
export 'presentation/screens/profile_screen.dart';
export 'presentation/widgets/add_expense_bottom_sheet.dart';
export 'presentation/widgets/create_group_bottom_sheet.dart';
export 'presentation/widgets/quick_ledger_dialog.dart';

// Hardware Triggers
export 'core/hardware/back_tap_channel.dart';

// State Management (Riverpod)
export 'presentation/providers/personal_ledger_state.dart';
export 'presentation/providers/personal_ledger_provider.dart';
export 'presentation/providers/expense_provider.dart';
export 'presentation/providers/sync_provider.dart';
export 'presentation/providers/auth_provider.dart';
export 'presentation/providers/group_list_provider.dart';

