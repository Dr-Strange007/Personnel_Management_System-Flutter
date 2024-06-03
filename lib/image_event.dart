part of 'image_bloc.dart';

abstract class ImageEvent extends Equatable {
  const ImageEvent();

  @override
  List<Object> get props => [];
}

class LoadImage extends ImageEvent {}

class RegisterImage extends ImageEvent {
  final XFile file;
  const RegisterImage(this.file);
}

class FetchUserDetailsEvent extends ImageEvent {
  @override
  List<Object> get props => [];
}