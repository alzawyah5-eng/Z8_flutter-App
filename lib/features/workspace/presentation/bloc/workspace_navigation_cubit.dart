import 'package:flutter_bloc/flutter_bloc.dart';

class WorkspaceNavigationState {
  const WorkspaceNavigationState({this.section = 'home', this.revision = 0});

  final String section;
  final int revision;

  WorkspaceNavigationState copyWith({String? section, int? revision}) =>
      WorkspaceNavigationState(
        section: section ?? this.section,
        revision: revision ?? this.revision,
      );
}

/// Owns workspace section navigation and refresh generations so view routing
/// follows the same Cubit pattern as authentication.
class WorkspaceNavigationCubit extends Cubit<WorkspaceNavigationState> {
  WorkspaceNavigationCubit() : super(const WorkspaceNavigationState());

  void openSection(String section) {
    emit(state.copyWith(section: section));
  }

  void refresh() {
    emit(state.copyWith(revision: state.revision + 1));
  }
}
