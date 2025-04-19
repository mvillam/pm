part of 'sm.dart';

abstract class Event {
  const Event();
}

class NullEvent extends Event {
  const NullEvent();
}

class InitialEvent extends Event {
  const InitialEvent();
}

abstract class ErrorEvent extends Event {
  final Object exception;
  const ErrorEvent({required this.exception});
  @override
  int get hashCode => exception.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ErrorEvent &&
              runtimeType == other.runtimeType &&
              exception == other.exception;
}

class PlatformErrorEvent extends ErrorEvent {
  const PlatformErrorEvent({required super.exception});
}