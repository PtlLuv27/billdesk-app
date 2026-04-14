import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../models/company_model.dart';

// 1. The modern Notifier (Replaces StateNotifier)
class CompanyNotifier extends Notifier<List<Company>> {
  @override
  List<Company> build() {
    // Fetch data as soon as the provider is initialized
    _loadCompanies();
    return []; // Initial empty state before data loads
  }

  // Fetch active companies from SQLite
  Future<void> _loadCompanies() async {
    final companies = await DatabaseHelper.instance.getAllActiveCompanies();
    state = companies; // 'state' is built into Notifier
  }

  // Add a new company to SQLite and update the UI state
  Future<void> addCompany(Company newCompany) async {
    await DatabaseHelper.instance.insertCompany(newCompany);
    // Refresh the list
    await _loadCompanies(); 
  }

  // Update an existing company in SQLite and refresh UI
  Future<void> updateCompany(Company updatedCompany) async {
    await DatabaseHelper.instance.updateCompany(updatedCompany);
    // Refresh the list so the dashboard reflects the changes
    await _loadCompanies(); 
  }

}

// 2. The modern Provider (Replaces StateNotifierProvider)
final companyProvider = NotifierProvider<CompanyNotifier, List<Company>>(() {
  return CompanyNotifier();
});

// 3. The modern Notifier for Active Company (Replaces StateProvider)
class ActiveCompanyNotifier extends Notifier<Company?> {
  @override
  Company? build() {
    return null; // No company selected by default
  }

  // Call this when the user logs into a specific company
  void setCompany(Company? company) {
    state = company;
  }
}

// 4. The modern Provider for the active company
final activeCompanyProvider = NotifierProvider<ActiveCompanyNotifier, Company?>(() {
  return ActiveCompanyNotifier();
});