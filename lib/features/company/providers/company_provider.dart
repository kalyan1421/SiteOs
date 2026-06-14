import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/repositories/company_repository.dart';

final companyRepositoryProvider =
    Provider<CompanyRepository>((ref) => CompanyRepository());

/// The current user's company row (null until they belong to one).
final currentCompanyProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final companyId = ref.watch(userProfileProvider)?.companyId;
  if (companyId == null) return null;
  return ref.watch(companyRepositoryProvider).getCompany(companyId);
});
