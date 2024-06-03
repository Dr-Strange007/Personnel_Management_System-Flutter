part of 'image_bloc.dart';

abstract class ImageState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ImageInitial extends ImageState {}

class ImageLoaded extends ImageState {
  final String imagePath;
  ImageLoaded(this.imagePath);

  @override
  List<Object?> get props => [imagePath];
}

class FaceRegistrationNeeded extends ImageState {} // New state for unregistered users


class FaceRegistrationLoading extends ImageState {}

class FaceRegistrationSuccess extends ImageState {
  final String imagePath;
  FaceRegistrationSuccess(this.imagePath);

  @override
  List<Object?> get props => [imagePath];
}

class FaceRegistrationFailure extends ImageState {
  final String error;
  FaceRegistrationFailure(this.error);

  @override
  List<Object?> get props => [error];
}

class ImageError extends ImageState {
  final String error;
  ImageError(this.error);

  @override
  List<Object?> get props => [error];
}

class MatchingInProgress extends ImageState {}
