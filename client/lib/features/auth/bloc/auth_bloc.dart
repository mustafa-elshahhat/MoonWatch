import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/security/credential_store.dart';
import '../../iptv/service/iptv_api_service.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginSubmitted extends AuthEvent {
  final String username;
  final String password;
  const AuthLoginSubmitted(this.username, this.password);
  @override
  List<Object?> get props => [username, password];
}

class AuthLogoutRequested extends AuthEvent {}

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final CredentialStore _credentialStore;
  final IptvApiService _iptvApiService;

  AuthBloc({
    required CredentialStore credentialStore,
    required IptvApiService iptvApiService,
  })  : _credentialStore = credentialStore,
        _iptvApiService = iptvApiService,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginSubmitted>(_onLoginSubmitted);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onCheckRequested(
      AuthCheckRequested event, Emitter<AuthState> emit) async {
    final hasCreds = await _credentialStore.hasIptvCredentials();
    if (hasCreds) {
      emit(AuthAuthenticated());
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginSubmitted(
      AuthLoginSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final username = event.username.trim();
      final password = event.password;

      if (username.isEmpty || password.isEmpty) {
        emit(const AuthError('Username and password are required.'));
        return;
      }

      final success =
          await _iptvApiService.verifyCredentials(username, password);

      if (success) {
        await _credentialStore.saveIptvCredentials(username, password);
        _iptvApiService.clearConfig();
        emit(AuthAuthenticated());
      } else {
        emit(const AuthError('Invalid IPTV username or password.'));
      }
    } catch (e) {
      emit(const AuthError('Could not connect to IPTV provider.'));
    }
  }

  Future<void> _onLogoutRequested(
      AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _credentialStore.clearIptvCredentials();
    emit(AuthUnauthenticated());
  }
}
