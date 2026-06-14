import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/client_bill.dart';
import '../data/models/client_photo.dart';
import '../data/models/client_project.dart';
import '../data/repositories/client_portal_repository.dart';

/// Singleton repository for the read-only client portal.
final clientPortalRepositoryProvider =
    Provider<ClientPortalRepository>((ref) => ClientPortalRepository());

/// Projects the signed-in client has been granted access to.
final clientProjectsProvider =
    FutureProvider<List<ClientProject>>((ref) async {
  return ref.watch(clientPortalRepositoryProvider).fetchProjects();
});

/// A single assigned project by id.
final clientProjectProvider =
    FutureProvider.family<ClientProject?, String>((ref, projectId) async {
  return ref.watch(clientPortalRepositoryProvider).fetchProject(projectId);
});

/// Read-only photo / document timeline for an assigned project.
final clientPhotosProvider =
    FutureProvider.family<List<ClientPhoto>, String>((ref, projectId) async {
  return ref.watch(clientPortalRepositoryProvider).fetchPhotos(projectId);
});

/// Read-only RA / progress bill status list for an assigned project.
final clientBillsProvider =
    FutureProvider.family<List<ClientBill>, String>((ref, projectId) async {
  return ref.watch(clientPortalRepositoryProvider).fetchBills(projectId);
});
