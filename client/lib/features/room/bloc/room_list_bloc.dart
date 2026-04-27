import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repository/room_repository.dart';


abstract class RoomListEvent extends Equatable {
  const RoomListEvent();
  @override
  List<Object?> get props => [];
}

class RoomListFetch extends RoomListEvent {
  final bool silent;
  const RoomListFetch({this.silent = false});
  @override
  List<Object?> get props => [silent];
}


abstract class RoomListState extends Equatable {
  const RoomListState();
  @override
  List<Object?> get props => [];
}

class RoomListInitial extends RoomListState {}

class RoomListLoading extends RoomListState {}

class RoomListLoaded extends RoomListState {
  final List<Map<String, dynamic>> rooms;
  const RoomListLoaded(this.rooms);
  @override
  List<Object?> get props => [rooms];
}

class RoomListError extends RoomListState {
  final String message;
  const RoomListError(this.message);
  @override
  List<Object?> get props => [message];
}


class RoomListBloc extends Bloc<RoomListEvent, RoomListState> {
  final RoomRepository _repository;

  RoomListBloc({required RoomRepository repository})
      : _repository = repository,
        super(RoomListInitial()) {
    on<RoomListFetch>(_onFetch);
  }

  Future<void> _onFetch(
    RoomListFetch event,
    Emitter<RoomListState> emit,
  ) async {
    if (!event.silent) {
      emit(RoomListLoading());
    }
    try {
      final rooms = await _repository.listRooms();
      emit(RoomListLoaded(rooms));
    } catch (e) {
      if (!event.silent) {
        emit(
          const RoomListError('Could not load rooms. Check your connection.'),
        );
      }
    }
  }
}
