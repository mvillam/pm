import 'package:flutter/material.dart';
import '../arch/sm_core/sm.dart' as sm;

class Idle extends sm.State {}
class Inactive extends sm.State {}
class Active extends sm.State {}

class SmWidget extends StatelessWidget {
  final sm.StateMachine machine;

  const SmWidget({super.key, required this.machine});

  @override
  Widget build(BuildContext context) {
    return Center( child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Text(
          'La máquina se encuentra en estado:',
        ),
        Text(
          machine.value.toString(),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(
          '¿Está La máquina en estado Active? ${machine.isInState(Active)}',
        ),
      ],
    ),);
  }
}

