import 'package:flutter/foundation.dart';
import '../services/api_service.dart' as api;
import '../services/storage_service.dart';

/// Authentication state enum
enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Authentication Provider - Manages user authentication state
class AuthProvider extends ChangeNotifier {
  final api.CampXApiService _apiService = api.CampXApiService();
  final StorageService _storageService = StorageService();

  AuthState _state = AuthState.initial;
  String? _errorMessage;
  String? _username;

  AuthState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get username => _username;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;

  /// Initialize - Check for stored credentials and try silent login
  Future<void> initialize() async {
    print('AuthProvider: Starting initialization');
    _state = AuthState.loading;
    notifyListeners();

    try {
      await Future.any([
        _doInitialize(),
        Future.delayed(const Duration(seconds: 15), () => throw Exception('Auth initialization timed out')),
      ]);
    } catch (e) {
      print('AuthProvider: Initialization error: $e');
      _errorMessage = e.toString();
      _state = AuthState.unauthenticated;
    }
    
    notifyListeners();
  }

  Future<void> _doInitialize() async {
    final hasCredentials = await _storageService.hasStoredCredentials();
    print('AuthProvider: Has stored credentials? $hasCredentials');
    
    if (hasCredentials) {
      // Try silent login with stored credentials
      final username = await _storageService.getUsername();
      final password = await _storageService.getPassword();
      print('AuthProvider: Attempting silent login for $username');
      
      if (username != null && password != null) {
        _username = username;
        final result = await _apiService.login(username, password);
        print('AuthProvider: Silent login result: ${result['success']}');
        
        if (result['success']) {
          // Save session key
          await _storageService.saveSessionKey(result['sessionKey']);
          _state = AuthState.authenticated;
          print('AuthProvider: Initialization complete - authenticated');
          return;
        }
      }
    }
    
    // No stored credentials or login failed
    print('AuthProvider: Initialization complete - unauthenticated');
    _state = AuthState.unauthenticated;
  }

  /// Login with credentials
  Future<bool> login(String username, String password) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.login(username, password);
      
      print('AuthProvider: Login result = $result');
      
      if (result['success']) {
        // Save credentials securely
        await _storageService.saveUsername(username);
        await _storageService.savePassword(password);
        await _storageService.saveSessionKey(result['sessionKey']);
        
        _username = username;
        _state = AuthState.authenticated;
        print('AuthProvider: Login successful, state = authenticated');
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Login failed';
        _state = AuthState.error;
        print('AuthProvider: Login failed - ${result['message']}');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  /// Silent re-authentication (for session refresh)
  Future<bool> reauthenticate() async {
    try {
      final username = await _storageService.getUsername();
      final password = await _storageService.getPassword();
      
      if (username == null || password == null) {
        return false;
      }
      
      final result = await _apiService.login(username, password);
      
      if (result['success']) {
        await _storageService.saveSessionKey(result['sessionKey']);
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    _state = AuthState.loading;
    notifyListeners();

    try {
      _apiService.logout();
      await _storageService.clearSession();
      _state = AuthState.unauthenticated;
    } catch (e) {
      _state = AuthState.unauthenticated;
    }
    
    notifyListeners();
  }

  /// Clear stored credentials (full logout)
  Future<void> clearCredentials() async {
    await _storageService.clearAll();
    _apiService.logout();
    _username = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  /// Check if has stored credentials
  Future<bool> hasStoredCredentials() async {
    return await _storageService.hasStoredCredentials();
  }
}
