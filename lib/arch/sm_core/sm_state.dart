part of 'sm.dart';

abstract class State {
  const State();
}

class ConfigurationState extends State {
  const ConfigurationState();
}

abstract class StateNode<S extends State> {
  void initial<I extends State>();
  void state<I extends State>(
      {StateBuilder? builder, required StateNodeType type});
  void on<E extends Event, T extends State>({
    TransitionType type,
    GuardCondition<E>? condition,
    List<Action<E>>? actions,
  });

  void always<T extends State>({
    GuardCondition<NullEvent>? condition,
    List<Action<NullEvent>>? actions,
  });

  void onEntry(OnEntryAction onEntry);

  void onExit(OnExitAction onExit);

  void onDone<E extends Event>({required List<Action<E>> actions});

  void invoke<Result>({InvokeBuilder? builder});
  void validate();
}

class StateNodeDefinition<S extends State> implements StateNode<S> {
  Type? _initialState;
  late final Type stateType;
  late final List<StateNodeDefinition> path;
  late final Set<Type> fullPathStateType = (() {
    return {
      ...path.map((e) => e.stateType).toSet(),
      stateType,
    };
  })();
  StateNodeDefinition? parentNode;
  Map<Type, StateNodeDefinition> childNodes = {};
  final Map<Type, List<TransitionDefinition>> eventTransitionsMap = {};
  InvokeDefinition? invokeDefinition;
  OnEntryAction? _onEntryAction;
  OnExitAction? _onExitAction;
  OnDone? onDoneCallback;
  StateNodeType stateNodeType;
  List<StateNodeDefinition> initialStateNodes = [];

  StateNodeDefinition get rootNode => path.isEmpty ? this : path.first;

  StateNodeDefinition({
    this.parentNode,
    required this.stateNodeType,
  })  : stateType = S,
        path = parentNode == null ? [] : [...parentNode.path, parentNode];

  @override
  void initial<I extends State>() {
    _initialState = I;
  }

  @override
  void state<NewStateType extends State>({
    StateBuilder? builder,
    required StateNodeType type,
  }) {
    final newStateNode = StateNodeDefinition<NewStateType>(
      parentNode: this,
      stateNodeType: type,
    );

    childNodes[NewStateType] = newStateNode;
    builder?.call(newStateNode);
  }

  void resetInitialStateNodes() {
    switch (stateNodeType) {
      case StateNodeType.parallel:
        final result = childNodes.values.toList();
        for (final childNode in childNodes.values) {
          result.addAll(childNode.initialStateNodes);
        }
        initialStateNodes = result;
        break;
      case StateNodeType.compound:
        final StateNodeDefinition node;
        final initial = _initialState;
        if (initial != null) {
          if (!childNodes.containsKey(initial)) {
            throw UnreachableInitialStateException(
                initialState: initial, currentState: stateType);
          }
          node = childNodes[initial]!;
        } else {
          node = childNodes.values.first;
        }
        final List<StateNodeDefinition> result = [node];
        result.addAll(node.initialStateNodes);
        initialStateNodes = result;
        break;
      case StateNodeType.atomic:
        if (childNodes.isNotEmpty) {
          throw AtomicValidationException();
        } else {
          final initial = _initialState;
          if ((initial != null) && !childNodes.containsKey(initial)) {
            throw UnreachableInitialStateException(
                initialState: initial, currentState: stateType);
          }
        }
        break;
      case StateNodeType.terminal:
        break;
    }
  }

  @override
  void on<E extends Event, TargetState extends State>({
    TransitionType? type,
    GuardCondition<E>? condition,
    List<Action<E>>? actions,
  }) {
    final onTransition = TransitionDefinition<S, E, TargetState>(
      sourceStateNode: this,
      targetState: TargetState,
      condition: condition,
      actions: actions,
      type: type,
    );

    eventTransitionsMap[E] ??= <TransitionDefinition>[];
    eventTransitionsMap[E]!.add(onTransition);
  }

  @override
  void always<TargetState extends State>({
    GuardCondition<NullEvent>? condition,
    List<Action<NullEvent>>? actions,
  }) {
    final onTransition = TransitionDefinition<S, NullEvent, TargetState>(
      sourceStateNode: this,
      targetState: TargetState,
      condition: condition,
      actions: actions,
    );

    eventTransitionsMap[NullEvent] ??= <TransitionDefinition>[];
    eventTransitionsMap[NullEvent]!.add(onTransition);
  }

  @override
  void onEntry(OnEntryAction onEntry) {
    _onEntryAction = onEntry;
  }

  @override
  void onExit(OnExitAction onExit) {
    _onExitAction = onExit;
  }

  @override
  void onDone<E extends Event>({required List<Action<E>> actions}) {
    onDoneCallback = OnDone<E>(actions: actions);
  }

  void callEntryAction<E extends Event>(
    StateMachineValue value,
    E event,
  ) {
    _onEntryAction?.call(event);
    if (invokeDefinition != null) {
      invokeDefinition?.execute(value, event);
    }
  }

  void callExitAction<E extends Event>(E event) {
    _onExitAction?.call(event);
  }

  void callDoneActions<E extends Event>(E event) {
    final actions = onDoneCallback?.actions ?? [];
    for (final action in actions) {
      action.call(event);
    }
  }

  List<TransitionDefinition> getCandidates<E>() {
    if (stateNodeType == StateNodeType.terminal) {
      return [];
    }

    return eventTransitionsMap[E] ?? [];
  }

  List<TransitionDefinition> getTransitions<E extends Event>(E event) {
    final transitions = <TransitionDefinition>[];

    for (final node in [this, ...path.reversed]) {
      final candidates = node.getCandidates<E>();

      final transition = candidates.firstWhereOrNull((item) {
        final dynamic condition = (item as dynamic).condition;

        if (condition != null && condition(event) == false) {
          return false;
        }

        return true;
      });

      if (transition != null) {
        transitions.add(transition);
      }
    }

    return transitions;
  }

  @override
  void invoke<Result>({InvokeBuilder? builder}) {
    invokeDefinition = InvokeDefinition<S, Event, Result>(
      sourceStateNode: this,
    );

    builder?.call(invokeDefinition!);
  }

  @override
  String toString() {
    if (path.isEmpty) {
      return stateType.toString();
    }
    if (path.last.toString() == "ConfigurationState") {
      return '>> $stateType';
    }
    return '${path.last} > $stateType';
  }



  @override
  void validate() {
    resetInitialStateNodes();
  }
}
