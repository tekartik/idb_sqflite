import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  /// Get the best factory
  late SdbFactory factory;
  if (kIsWeb) {
    factory = sdbFactoryWeb;
  } else {
    if (Platform.isWindows || Platform.isLinux) {
      // Use sqflite_common_ffi on Windows and Linux
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    factory = sdbFactorySqflite;
  }
  var bloc = MyAppBloc(factory);
  runApp(MyApp(
    bloc: bloc,
  ));
}

var valueKey = 'value';
var store = SdbStoreRef<String, int>('counter');
var record = store.record(valueKey);

class MyAppBloc {
  final SdbFactory factory;
  MyAppBloc(this.factory) {
    // Load counter on start
    () async {
      var db = await database;
      var value = ((await record.get(db))?.value) ?? 0;
      _counterController.add(value);
    }();
  }

  late final Future<SdbDatabase> database =
      factory.openDatabase('counter.db', version: 1, onVersionChange: (event) {
    var db = event.db;
    db.createStore(store);
  });

  final StreamController<int?> _counterController =
      StreamController<int>.broadcast();

  Stream<int?> get counter => _counterController.stream;

  Future increment() async {
    var db = await database;
    var value = await db.inStoreTransaction(store, SdbTransactionMode.readWrite,
        (txn) async {
      var value = (await record.getValue(txn)) ?? 0;
      value++;
      await record.put(txn, value);
      return value;
    });

    _counterController.add(value);
  }
}

class MyApp extends StatelessWidget {
  final MyAppBloc bloc;

  const MyApp({super.key, required this.bloc});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(
        title: 'Flutter Demo Home Page',
        bloc: bloc,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final MyAppBloc bloc;

  const MyHomePage({super.key, this.title, required this.bloc});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String? title;

  @override
  // ignore: library_private_types_in_public_api
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int?>(
        stream: widget.bloc.counter,
        builder: (context, snapshot) {
          var count = snapshot.data;
          return Scaffold(
            appBar: AppBar(
              // Here we take the value from the MyHomePage object that was created by
              // the App.build method, and use it to set our appbar title.
              title: Text(widget.title!),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text(
                    'You have pushed the button this many times:',
                  ),
                  if (count != null)
                    Text('$count',
                        style: Theme.of(context).textTheme.headlineSmall)
                ],
              ),
            ),
            floatingActionButton: count != null
                ? FloatingActionButton(
                    onPressed: () {
                      widget.bloc.increment();
                    },
                    tooltip: 'Increment',
                    child: const Icon(Icons.add),
                  )
                : null,
          );
        });
  }
}
