import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../models/company_model.dart';
import '../../authentication/providers/auth_provider.dart'; 

class CompanyNotifier extends Notifier<List<Company>> {
  @override
  List<Company> build() {
    final userId = ref.watch(authProvider);
    
    if (userId != null) {
      _loadCompanies(userId);
    }
    
    return []; 
  }

  Future<void> _loadCompanies(String userId) async {
    final companies = await DatabaseHelper.instance.getCompaniesByUser(userId);
    state = companies; 
  }

  Future<void> addCompany(Company newCompany) async {
    await DatabaseHelper.instance.insertCompany(newCompany);
    final userId = ref.read(authProvider);
    if (userId != null) await _loadCompanies(userId); 
  }

  Future<void> updateCompany(Company updatedCompany) async {
    await DatabaseHelper.instance.updateCompany(updatedCompany);
    final userId = ref.read(authProvider);
    if (userId != null) await _loadCompanies(userId); 
  }

  Future<void> deleteCompany(Company company) async {
    final updatedCompany = Company(
      id: company.id, userId: company.userId, name: company.name,
      address1: company.address1, address2: company.address2,
      mobileNumber: company.mobileNumber, gstin: company.gstin,
      bankName: company.bankName, accountNumber: company.accountNumber,
      ifscCode: company.ifscCode, pin: company.pin,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
      isDeleted: 1, // <-- Soft Delete Flag
    );
    await DatabaseHelper.instance.updateCompany(updatedCompany);
    final userId = ref.read(authProvider);
    if (userId != null) await _loadCompanies(userId); 
  }
}

final companyProvider = NotifierProvider<CompanyNotifier, List<Company>>(CompanyNotifier.new);

class ActiveCompanyNotifier extends Notifier<Company?> {
  @override
  Company? build() {
    return null; 
  }

  void setCompany(Company? company) {
    state = company;
  }
}

final activeCompanyProvider = NotifierProvider<ActiveCompanyNotifier, Company?>(ActiveCompanyNotifier.new);