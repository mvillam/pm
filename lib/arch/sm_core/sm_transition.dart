part of "sm.dart";

abstract class Transition{
   const Transition();
}

class TransitionDefinition<S extends State, E extends Event,TargetState extends State> extends Transition{
   final TransitionType type;
   Type targetState;
   final StateNodeDefinition<State> sourceStateNode;
   final GuardCondition<E>? condition;
   final List<Action<E>>? actions;
   Type get event => E;
   late final StateNodeDefinition targetStateNode = (() {
      StateNodeDefinition? targetLeaf;
      if (sourceStateNode.parentNode?.stateNodeType == StateNodeType.compound) {
         targetLeaf = _findLeaf(targetState, sourceStateNode.parentNode!);
      }

      targetLeaf ??= _findLeaf(targetState, sourceStateNode.rootNode);

      if (targetLeaf == null) {
         throw Exception('destination leaf node not found');
      }

      return targetLeaf;
   })();

   TransitionDefinition({
      required this.sourceStateNode,
      required this.targetState,
      TransitionType? type,
      this.condition,
      this.actions,
   }) : type = type ?? TransitionType.external;

   StateNodeDefinition? _findLeaf(Type state, StateNodeDefinition node) {
      final currentNode = node;
      for (final key in currentNode.childNodes.keys) {
         final childNode = currentNode.childNodes[key];
         if (key == state) {
            return childNode;
         }

         if (childNode != null) {
            final res = _findLeaf(state, childNode);
            if (res != null) {
               return res;
            }
         }
      }

      return null;
   }

   Set<StateNodeDefinition> _getExitNodes(
       StateMachineValue value,
       StateNodeDefinition source,
       StateNodeDefinition target,
       ) {
      final nodes = <StateNodeDefinition>{};
      final lcca = getLeastCommonCompoundAncestor(source, target);

      for (final node in value.activeNodes) {
         nodes.addAll(
            node.path.where((element) => element.path.contains(lcca)),
         );

         if (node.path.contains(lcca)) {
            nodes.add(node);
         }
      }

      if (type == TransitionType.internal) {
         nodes.remove(source);
      }

      return nodes;
   }

   Set<StateNodeDefinition> _getEntryNodes(
       StateMachineValue value,
       StateNodeDefinition source,
       StateNodeDefinition target,
       ) {
      final nodes = <StateNodeDefinition>{};

      final lcca = getLeastCommonCompoundAncestor(source, target);

      nodes.addAll(
         target.path.where(
                (element) {
               if (type == TransitionType.internal && element == source) {
                  return false;
               }
               return !lcca.path.contains(element);
            },
         ),
      );

      nodes.add(target);
      nodes.addAll(target.initialStateNodes);

      return nodes;
   }

   StateMachineValue trigger(StateMachineValue value, E e) {
      var sourceLeaf = sourceStateNode;
      final targetLeaf = targetStateNode;

      if (sourceLeaf.stateNodeType == StateNodeType.parallel &&
          targetLeaf.path.contains(sourceLeaf)) {
         sourceLeaf = [...targetLeaf.path, targetLeaf].firstWhere((node) {
            return !sourceStateNode.path.contains(node) && sourceStateNode != node;
         });
      }

      final exitNodes = _getExitNodes(value, sourceLeaf, targetLeaf);
      final entryNodes = _getEntryNodes(value, sourceLeaf, targetLeaf);

      for (final node in exitNodes) {
         node.callExitAction(e);
      }

      if (actions != null && actions!.isNotEmpty) {
         for (final action in actions!) {
            action(e);
         }
      }

      exitNodes.forEach(value.remove);
      entryNodes.forEach(value.add);

      for (final node in entryNodes) {
         node.callEntryAction(value, e);
      }

      for (final node in entryNodes) {
         final parentNode = node.parentNode;
         if (node.stateNodeType != StateNodeType.terminal || parentNode == null) {
            continue;
         }

         if (parentNode.stateNodeType == StateNodeType.compound ||
             parentNode == node.rootNode) {
            parentNode.callDoneActions(e);
         }

         if (parentNode.stateNodeType != StateNodeType.compound) {
            continue;
         }

         final parallelParentMachine = parentNode.parentNode;
         if (parallelParentMachine?.stateNodeType == StateNodeType.parallel) {
            var allParallelNodesInFinalState = true;
            for (final activeNode in value.activeNodes) {
               if (activeNode.path.contains(parallelParentMachine) &&
                   activeNode.stateNodeType != StateNodeType.terminal) {
                  allParallelNodesInFinalState = false;
                  break;
               }
            }

            if (allParallelNodesInFinalState) {
               parallelParentMachine?.callDoneActions(e);
            }
         }
      }

      return value;
   }
}


class InvokeDefinition<S extends State, E extends Event, Result> {
   late final String id;
   final StateNodeDefinition sourceStateNode;

   final Map<Type, TransitionDefinition> onDoneTransitionsMap = {};

   TransitionDefinition? onErrorTransition;

   late final InvokeSrcCallback<Result> _callback;

   InvokeDefinition({required this.sourceStateNode});

   void setId(String value) {
      id = value;
   }

   void src(InvokeSrcCallback<Result> callback) {
      _callback = callback;
   }

   void onDone<Target extends State, R>({
      List<Action<DoneInvokeEvent<R>>>? actions,
      GuardCondition<DoneInvokeEvent<R>>? condition,
   }) {
      onDoneTransitionsMap[Target] =
          TransitionDefinition<S, DoneInvokeEvent<R>, Target>(
             sourceStateNode: sourceStateNode,
             targetState: Target,
             actions: actions,
             condition: condition,
          );
   }

   void onError<Target extends State>({
      List<Action<ErrorEvent>>? actions,
   }) {
      onErrorTransition = TransitionDefinition<S, ErrorEvent, Target>(
         sourceStateNode: sourceStateNode,
         targetState: Target,
         actions: actions,
      );
   }

   void execute(StateMachineValue value, Event e) async {
      try {
         final result = await _callback(e);

         final doneInvokeEvent = DoneInvokeEvent<Result>(id: id, data: result);

         final matchedTransition = onDoneTransitionsMap.values.firstWhereOrNull(
                (element) {
               final dynamic condition = (element as dynamic).condition;

               if (condition != null && condition(doneInvokeEvent) == false) {
                  return false;
               }

               return true;
            },
         );

         if (matchedTransition == null) {
            return;
         }

         matchedTransition.trigger(value, doneInvokeEvent);
      } on Object catch (e) {
         onErrorTransition?.trigger(
            value,
            PlatformErrorEvent(exception: e),
         );
      }
   }
}

class OnDone<E extends Event> {
   final List<Action<E>>? actions;
   OnDone({required this.actions});
}

class DoneInvokeEvent<Result> extends Event {
   final String id;
   final Result data;
   const DoneInvokeEvent({required this.id, required this.data});
   @override
   int get hashCode => id.hashCode ^ data.hashCode;
   @override
   bool operator ==(Object other) =>
       identical(this, other) ||
           other is DoneInvokeEvent<Result> &&
               runtimeType == other.runtimeType &&
               id == other.id &&
               data == other.data;
}