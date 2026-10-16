import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:image_repository/image_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// The equipment filter (Swift `ListFilter`).
enum GymEquipmentFilter {
  /// Everything in the catalogue.
  all,

  /// Only what the gym has switched on.
  selected,
}

/// Where Continue has got to.
enum GymProfileEditorStatus {
  /// Being edited.
  editing,

  /// Continue is saving.
  continuing,

  /// Saved and made the usual gym: the caller moves on.
  continued,

  /// Continue's save failed: nothing moved on.
  continueFailure,
}

final class const GymProfileEditorState({
  required final GymProfileModel gym,
  final GymEquipmentFilter filter = GymEquipmentFilter.all,
  final String query = '',
  final bool hasUnsavedChanges = false,
  final GymProfileEditorStatus status = GymProfileEditorStatus.editing,

  /// The photo button was pressed: a photo is being picked, uploaded and
  /// saved.
  final bool savingPhoto = false,
}) extends Equatable {
  /// [list]'s rows, filtered and in name order.
  List<GymEquipmentItem> visible(GymEquipmentList list) =>
      GymEditorRules.visibleItems(
        gym,
        list,
        query: query,
        selectedOnly: filter == GymEquipmentFilter.selected,
      );

  /// Whether a query hid every section.
  bool get hidesEverything => GymEditorRules.hidesEverything(
    gym,
    query: query,
    selectedOnly: filter == GymEquipmentFilter.selected,
  );

  GymProfileEditorState copyWith({
    GymProfileModel? gym,
    GymEquipmentFilter? filter,
    String? query,
    bool? hasUnsavedChanges,
    GymProfileEditorStatus? status,
    bool? savingPhoto,
  }) => GymProfileEditorState(
    gym: gym ?? this.gym,
    filter: filter ?? this.filter,
    query: query ?? this.query,
    hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
    status: status ?? this.status,
    savingPhoto: savingPhoto ?? this.savingPhoto,
  );

  @override
  List<Object?> get props => [
    gym,
    filter,
    query,
    hasUnsavedChanges,
    status,
    savingPhoto,
  ];
}

/// One gym being edited, with every equipment editor pushed over it
/// writing here (Swift `GymProfilePresenter`, whose editors share its
/// bindings). Leaving saves what changed; Continue, offered when a gym is
/// being set up, saves it and makes it the usual gym.
class GymProfileEditorCubit extends Cubit<GymProfileEditorState> {
  new({
    required GymProfileModel gym,
    required this._uid,
    required this._setup,
    required this._analytics,
    required this._images,
    required this._picker,
    this._untitledName = 'Untitled Gym Profile',
    this._newId = newUuid,
    this._numbered,
  }) : super(GymProfileEditorState(gym: gym)) {
    _analytics.trackScreenView(const AnalyticsEvent('${_screen}_OnAppear'));
  }

  static const _screen = 'GymProfileView';

  final String _uid;
  final TrainingSetupService _setup;
  final AnalyticsRepository _analytics;
  final ImageRepository _images;
  final PhotoPicker _picker;
  final String _untitledName;
  final String Function() _newId;
  final String Function(String name, int number)? _numbered;

  void _emit(GymProfileEditorState state) {
    if (!isClosed) emit(state);
  }

  /// Applies [change] to the gym; any change waits to be saved.
  void edit(GymProfileModel Function(GymProfileModel gym) change) =>
      emit(state.copyWith(gym: change(state.gym), hasUnsavedChanges: true));

  /// The name in the title field.
  void renamed(String name) => edit((gym) => GymEditorRules.renamed(gym, name));

  void filterChanged(GymEquipmentFilter filter) =>
      emit(state.copyWith(filter: filter));

  void queryChanged(String query) => emit(state.copyWith(query: query));

  /// Switches item [id] of [list] on or off.
  void setActive(GymEquipmentList list, String id, {required bool isActive}) =>
      edit(
        (gym) =>
            GymEditorRules.settingActive(gym, list, id, isActive: isActive),
      );

  /// A second machine like [id] beside it, which nothing opens.
  void duplicateMachine(GymEquipmentList list, String id) => edit(
    (gym) => GymEditorRules.duplicatingMachine(
      gym,
      list,
      id,
      newId: _newId,
      numbered: _numbered,
    ).$1,
  );

  /// Adds a machine and returns its id, for its editor to open on.
  String addMachine(
    GymEquipmentList list, {
    required String name,
    String? worksAs,
  }) {
    final (gym, id) = GymEditorRules.addingMachine(
      state.gym,
      list,
      name: name,
      worksAs: worksAs,
      newId: _newId,
    );
    edit((_) => gym);
    return id;
  }

  /// Removes machine [id] if the user made it.
  void deleteMachine(GymEquipmentList list, String id) =>
      edit((gym) => GymEditorRules.deletingMachine(gym, list, id));

  /// Where a gym's photo is stored (`GymProfileManager.saveGymProfile`).
  static String photoPath(GymProfileModel gym) =>
      'users/${gym.authorId}/gymProfiles/${gym.id}';

  /// The photo button (`GymProfilePresenter.onImageSelectorChanged`): a
  /// photo from the library, uploaded, then saved on the gym with every
  /// edit so far, as Swift saves the whole profile with it. The draft takes
  /// the photo's address before the save, so a later save on leaving
  /// keeps it: those saves delete the fields a gym lacks.
  Future<void> photoPressed() async {
    if (state.savingPhoto) return;
    _analytics.analytic('${_screen}_ImageSelected_Start');
    var drafted = false;
    _emit(state.copyWith(savingPhoto: true));
    try {
      final photo = await _picker.pick(PhotoSource.library, PhotoSize.standard);
      if (photo == null) {
        _analytics.analytic('${_screen}_ImageSelected_Cancel');
        return;
      }
      final url = await _images.upload(photo, photoPath(state.gym));
      final gym = GymProfileModel.fromFirestore({
        ...state.gym.toFirestore(),
        GymProfileModelKeys.imageUrl: url,
      });
      _emit(state.copyWith(gym: gym, hasUnsavedChanges: false));
      drafted = true;
      await _setup.saveGymProfile(gym, untitledName: _untitledName);
      _analytics.analytic('${_screen}_ImageSelected_Success');
    } on Object catch (error) {
      _analytics.severe('${_screen}_ImageSelected_Fail', error);
      // A photo that reached the draft is saved again on leaving.
      if (drafted) _emit(state.copyWith(hasUnsavedChanges: true));
    } finally {
      _emit(state.copyWith(savingPhoto: false));
    }
  }

  /// The screen going: saves what changed. True when there was nothing to
  /// save or the save took; false when it failed, and the edit stays
  /// unsaved.
  Future<bool?> left() async {
    _analytics.trackEvent(const AnalyticsEvent('${_screen}_OnDisappear'));
    if (!state.hasUnsavedChanges) return null;
    return await _save();
  }

  Future<bool> _save() async {
    _emit(state.copyWith(hasUnsavedChanges: false));
    _analytics.analytic('${_screen}_Save_Start');
    try {
      await _setup.saveGymProfile(state.gym, untitledName: _untitledName);
    } on Object catch (error) {
      _analytics.severe('${_screen}_Save_Fail', error);
      _emit(state.copyWith(hasUnsavedChanges: true));
      return false;
    }
    _analytics.analytic('${_screen}_Save_Success');
    return true;
  }

  /// Saves the gym and makes it the user's usual one. A failed save stops
  /// there; a failed favourite is logged and passed over, as in Swift.
  Future<void> continuePressed() async {
    if (state.status == GymProfileEditorStatus.continuing ||
        state.status == GymProfileEditorStatus.continued) {
      return;
    }
    emit(state.copyWith(status: GymProfileEditorStatus.continuing));
    if (!await _save()) {
      _emit(state.copyWith(status: GymProfileEditorStatus.continueFailure));
      return;
    }
    _analytics.analytic('${_screen}_FavouriteGymProfile_Start');
    try {
      await _setup.setFavouriteGymProfile(_uid, state.gym.id);
      _analytics.analytic('${_screen}_FavouriteGymProfile_Success');
    } on Object catch (_) {
      _analytics.analytic('${_screen}_FavouriteGymProfile_Fail');
    }
    _emit(state.copyWith(status: GymProfileEditorStatus.continued));
  }

  /// Back to editing after a failed Continue was reported.
  void failureShown() =>
      emit(state.copyWith(status: GymProfileEditorStatus.editing));
}
