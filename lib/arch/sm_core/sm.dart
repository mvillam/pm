import 'dart:async';
import 'package:collection/collection.dart';

part 'sm_state.dart';
part 'sm_event.dart';
part 'sm_transition.dart';

enum StateNodeType { atomic, compound, parallel, terminal }

enum TransitionType { internal, external }

typedef StateMachineBuilder = void Function(StateNodeDefinition snd);
typedef StateBuilder<S extends State> = void Function(StateNode<S> s);
typedef InvokeBuilder = void Function(InvokeDefinition i);
typedef InvokeSrcCallback<Result> = Future<Result> Function(Event e);
typedef GuardCondition<E extends Event> = bool Function(E event);
typedef Action<E extends Event> = void Function(E event);
typedef OnEntryAction = void Function(Event? event);
typedef OnExitAction = void Function(Event? event);
typedef OnTransitionCallback = void Function(Event e, StateMachineValue value);

StateNodeDefinition getLeastCommonCompoundAncestor(
  StateNodeDefinition node1,
  StateNodeDefinition node2,
) {
  if (node1 == node2) {
    return node1;
  }

  late final List<StateNodeDefinition> fromPath;
  late final StateNodeDefinition targetNode;
  if (node1.path.length > node2.path.length) {
    fromPath = [...node1.path, node1];
    targetNode = node2;
  } else {
    fromPath = [...node2.path, node2];
    targetNode = node1;
  }

  for (var index = 0; index != fromPath.length; index += 1) {
    final node = fromPath[index];

    if (node.parentNode?.stateNodeType != StateNodeType.compound) {
      continue;
    }

    if (index >= targetNode.path.length || node != targetNode.path[index]) {
      return fromPath[index - 1];
    }
  }
  return fromPath.first;
}

abstract class ValidationException implements Exception {}

class AtomicValidationException implements ValidationException {
  @override
  String toString() => 'Atomic state can not hav e children';
}

class UnreachableInitialStateException implements ValidationException {
  final Type currentState;
  final Type initialState;

  const UnreachableInitialStateException({
    required this.currentState,
    required this.initialState,
  });

  @override
  String toString() =>
      'Initial state "$initialState" not found on "$currentState"';
}

class StateMachineValue {
  late final List<StateNodeDefinition> _activeNodes;

  StateMachineValue(StateNodeDefinition node) : _activeNodes = [node];
  Iterable<StateNodeDefinition> get activeNodes => _activeNodes;

  bool isInState(Type S) {
    for (final node in _activeNodes) {
      if (node.stateType == S) {
        return true;
      }

      if (node.fullPathStateType.contains(S)) {
        return true;
      }
    }
    return false;
  }

  bool matchesStatePath(List<Type> path) {
    final pathSet = path.toSet();
    for (final node in _activeNodes) {
      if (node.fullPathStateType.containsAll(pathSet)) {
        return true;
      }
    }
    return false;
  }

  void add(StateNodeDefinition node) {
    final duppedNodes = node.path.where(
      (path) => _activeNodes.any((element) => element == path),
    );
    duppedNodes.forEach(remove);

    _activeNodes.add(node);
  }

  void remove(StateNodeDefinition node) {
    final toRemove = [node];
    for (final activeNode in _activeNodes) {
      if (activeNode.path.contains(node)) {
        toRemove.add(activeNode);
      }
    }

    toRemove.forEach(_activeNodes.remove);
  }

  @override
  String toString() {
    return _activeNodes.join('\n');
  }
}

class StateMachine {
  String name;
  String? id;
  late StateMachineValue value;
  late StateNodeDefinition<ConfigurationState> rootNode;
  final StreamController<StateMachineValue> _controller =
      StreamController.broadcast();

  Stream<StateMachineValue> get stream => _controller.stream;

  OnTransitionCallback? onTransition;



  StateMachine._(
      {required this.rootNode,
      required this.name,
      this.id,
      this.onTransition}) {
    value = StateMachineValue(rootNode);

    final entryNodes = rootNode.initialStateNodes;
    for (final node in entryNodes) {
      node.callEntryAction(value, const InitialEvent());
      value.add(node);
    }
    send(const NullEvent());
  }



  factory StateMachine.create(
    StateMachineBuilder builder, {
    required String name,
    String? id,
    OnTransitionCallback? onTransition,
  }) {
    final rootNode = StateNodeDefinition<ConfigurationState>(
        stateNodeType: StateNodeType.compound);
    builder(rootNode);

    return StateMachine._(
        name: name, rootNode: rootNode, id: id, onTransition: onTransition);
  }

  void dispose() {
    _controller.close();
  }

  void send<E extends Event>(E event) {
    final nodes = value.activeNodes;

    final transitions = <TransitionDefinition>{};
    for (final node in nodes) {
      transitions.addAll(node.getTransitions(event));
    }

    if (transitions.isEmpty) {
      return;
    }

    for (final transition in transitions) {
      value = transition.trigger(value, event);
      onTransition?.call(event, value);

      _controller.add(value);
    }

    if (E != NullEvent) {
      send(const NullEvent());
    }
  }

  bool isInState(Type type) {
    return value.isInState(type);
  }

  bool matchesStatePath(List<Type> path) {
    return value.matchesStatePath(path);
  }

  void validate() {
    rootNode.validate();
  }

  @override
  String toString() {
    return rootNode.toString();
  }
}
