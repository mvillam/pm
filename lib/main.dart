import 'package:flutter/material.dart';
import 'package:pm/sm_flutter/sm_flutter.dart';
import 'package:pm/sm_flutter/sm_widget.dart';

import 'arch/sm_core/sm.dart' as sm;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  late sm.StateMachine stateMachine;

  @override
  void initState() {
    super.initState();
      stateMachine = sm.StateMachine.create(
      name: "MVM",
      id: widget.key.toString(),
          (g) => g
        ..initial<Idle>()
        ..state<Idle>(
            builder: (sb) => sb
              ..on<OnTap, Inactive>(
                  actions: [<sb>(e) => debugPrint("action --> ${e.toString()}")])
              ..onEntry((e) => debugPrint(
                  "entry -> ${sb.toString()} when -> ${e.toString()}"))
              ..onExit((e) => debugPrint(
                  "exit -> ${sb.toString()} when -> ${e.toString()}")),
            type: sm.StateNodeType.atomic)
        ..state<Inactive>(
            builder: (sb) => sb
              ..on<OnTap, Active>()
              ..onEntry((e) => debugPrint(
                  "entry -> ${sb.toString()} when -> ${e.toString()}"))
              ..onExit((e) => debugPrint(
                  "exit -> ${sb.toString()} when -> ${e.toString()}")),
            type: sm.StateNodeType.atomic)
        ..state<Active>(
            builder: (sb) => sb
              ..on<OnTap, Inactive>()
              ..invoke<String>(
                  builder: (b) => b
                    ..setId("saludo")
                    ..src((e) {
                      debugPrint(
                          "${b.id} -----------------------> ${e.toString()}");
                      return Future<String>.value("Aqui");
                    }))
              ..onEntry((e) => debugPrint(
                  "entry -> ${sb.toString()} when -> ${e.toString()}"))
              ..onExit((e) => debugPrint(
                  "exit -> ${sb.toString()} when -> ${e.toString()}")),
            type: sm.StateNodeType.atomic)
        ..validate(),
    );

  }

  @override
  Widget build(BuildContext context) {
    final smw = SmWidget(machine: stateMachine);
    FloatingActionButton b = FloatingActionButton(
      tooltip: 'Increment',
      onPressed: () {
        setState(() {
          stateMachine.send(OnTap());
        });
      },
      child: const Icon(Icons.add),
    );
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[smw],
          ),
        ),
        floatingActionButton: b);
  }
}
