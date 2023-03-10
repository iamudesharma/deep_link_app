// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uni_links/uni_links.dart';

bool _initialUriIsHandled = false;

void main() =>
    runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: MyApp()));

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  Uri? _initialUri;
  Uri? _latestUri;
  Object? _err;

  StreamSubscription? _sub;

  final _scaffoldKey = GlobalKey();
  final _cmds = getCmds();
  final _cmdStyle = const TextStyle(
      fontFamily: 'Courier', fontSize: 12.0, fontWeight: FontWeight.w700);

  @override
  void initState() {
    super.initState();
    _handleIncomingLinks();
    _handleInitialUri();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Handle incoming links - the ones that the app will recieve from the OS
  /// while already started.
  void _handleIncomingLinks() {
    if (!kIsWeb) {
      // It will handle app links while the app is already started - be it in
      // the foreground or in the background.
      _sub = uriLinkStream.listen((Uri? uri) {
        if (!mounted) return;
        print('got uri: $uri');
        setState(() {
          _latestUri = uri;
          _err = null;
        });

        if (uri!.queryParameters["user"] != null) {
          final user = uri.queryParameters['user'];
          final openDialog = uri.queryParameters['dialog'];
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => ProfilePage(
                openDialog:
                    openDialog != null || openDialog == "true" ? true : false,
                userName: user),
          ));
        }
      }, onError: (Object err) {
        if (!mounted) return;
        print('got err: $err');
        setState(() {
          _latestUri = null;
          if (err is FormatException) {
            _err = err;
          } else {
            _err = null;
          }
        });
      });
    }
  }

  /// Handle the initial Uri - the one the app was started with
  ///
  /// **ATTENTION**: `getInitialLink`/`getInitialUri` should be handled
  /// ONLY ONCE in your app's lifetime, since it is not meant to change
  /// throughout your app's life.
  ///
  /// We handle all exceptions, since it is called from initState.
  Future<void> _handleInitialUri() async {
    // In this example app this is an almost useless guard, but it is here to
    // show we are not going to call getInitialUri multiple times, even if this
    // was a weidget that will be disposed of (ex. a navigation route change).
    if (!_initialUriIsHandled) {
      _initialUriIsHandled = true;
      _showSnackBar('_handleInitialUri called');
      try {
        final uri = await getInitialUri();
        if (uri == null) {
          print('no initial uri');
        } else {
          print('got initial uri: $uri');
        }
        if (!mounted) return;
        setState(() => _initialUri = uri);

        if (uri!.queryParameters["user"] != null) {
          final user = uri.queryParameters['user'];
          final openDialog = uri.queryParameters['dialog'];
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => ProfilePage(
                openDialog:
                    openDialog != null || openDialog == "true" ? true : false,
                userName: user),
          ));
        }
      } on PlatformException {
        // Platform messages may fail but we ignore the exception
        print('falied to get initial uri');
      } on FormatException catch (err) {
        if (!mounted) return;
        print('malformed initial uri');
        setState(() => _err = err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final queryParams = _latestUri?.queryParametersAll.entries.toList();

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Deep Link'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const ProfilePage(openDialog: true),
                    ));
                  },
                  child: const Text("Go to ")),
            ),
          )
        ],
      ),
      body: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(8.0),
        children: [
          if (_err != null)
            ListTile(
              title: const Text('Error', style: TextStyle(color: Colors.red)),
              subtitle: Text('$_err'),
            ),
          ListTile(
            title: const Text('Initial Uri'),
            subtitle: Text('$_initialUri'),
          ),
          if (!kIsWeb) ...[
            ListTile(
              title: const Text('Latest Uri'),
              subtitle: Text('$_latestUri'),
            ),
            ListTile(
              title: const Text('Latest Uri (path)'),
              subtitle: Text('${_latestUri?.path}'),
            ),
            ExpansionTile(
              initiallyExpanded: true,
              title: const Text('Latest Uri (query parameters)'),
              children: queryParams == null
                  ? const [ListTile(dense: true, title: Text('null'))]
                  : [
                      for (final item in queryParams)
                        ListTile(
                          title: Text(item.key),
                          trailing: Text(item.value.join(', ')),
                        )
                    ],
            ),
          ],
          _cmdsCard(_cmds),
          const Divider(),
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.error, color: Colors.red),
              title: const Text(
                'Force quit this example app',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                // WARNING: DO NOT USE this in production !!!
                //          Your app will (most probably) be rejected !!!
                if (Platform.isIOS) {
                  exit(0);
                } else {
                  SystemNavigator.pop();
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _cmdsCard(List<String>? commands) {
    Widget platformCmds;

    if (commands == null) {
      platformCmds = const Center(child: Text('Unsupported platform'));
    } else {
      platformCmds = Column(
        children: [
          const [
            if (kIsWeb)
              Text('Append this path to the Web app\'s URL, replacing `#/`:\n')
            else
              Text('To populate above fields open a terminal shell and run:\n'),
          ],
          intersperse(
              commands.map<Widget>((cmd) => InkWell(
                    onTap: () => _printAndCopy(cmd),
                    child: Text('\n$cmd\n', style: _cmdStyle),
                  )),
              const Text('or')),
          [
            Text(
              '(tap on any of the above commands to print it to'
              ' the console/logger and copy to the device clipboard.)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.caption,
            ),
          ]
        ].expand((el) => el).toList(),
      );
    }

    return Card(
      margin: const EdgeInsets.only(top: 20.0),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: platformCmds,
      ),
    );
  }

  Future<void> _printAndCopy(String cmd) async {
    print(cmd);

    await Clipboard.setData(ClipboardData(text: cmd));
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to Clipboard')),
    );
  }

  void _showSnackBar(String msg) {
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      final context = _scaffoldKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
        ));
      }
    });
  }
}

List<String>? getCmds() {
  late final String cmd;
  var cmdSuffix = '';

  const plainPath = 'path/subpath';
  const args = 'path/portion/?uid=123&token=abc';
  const emojiArgs =
      '?arr%5b%5d=123&arr%5b%5d=abc&addr=1%20Nowhere%20Rd&addr=Rand%20City%F0%9F%98%82';

  if (kIsWeb) {
    return [
      plainPath,
      args,
      emojiArgs,
      // Cannot create malformed url, since the browser will ensure it is valid
    ];
  }

  if (Platform.isIOS) {
    cmd = '/usr/bin/xcrun simctl openurl booted';
  } else if (Platform.isAndroid) {
    cmd = '\$ANDROID_HOME/platform-tools/adb shell \'am start'
        ' -a android.intent.action.VIEW'
        ' -c android.intent.category.BROWSABLE -d';
    cmdSuffix = "'";
  } else {
    return null;
  }

  // https://orchid-forgery.glitch.me/mobile/redirect/
  return [
    '$cmd "http://host/$plainPath"$cmdSuffix',
    '$cmd "http://deeplink.com/$args"$cmdSuffix',
    '$cmd "http://deeplink.com/$emojiArgs"$cmdSuffix',
    '$cmd "http://@@malformed.invalid.url/path?"$cmdSuffix',
  ];
}

List<Widget> intersperse(Iterable<Widget> list, Widget item) {
  final initialValue = <Widget>[];
  return list.fold(initialValue, (all, el) {
    if (all.isNotEmpty) all.add(item);
    all.add(el);
    return all;
  });
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    Key? key,
    required this.openDialog,
    this.userName,
  }) : super(key: key);

  final bool openDialog;
  final String? userName;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  showDialWidget() async {
    if (mounted) {
      Future.microtask(() {
        showAboutDialog(
          context: context,
        );
      });
    }
  }

  @override
  void initState() {
    if (widget.openDialog) {
      showDialWidget();
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          child: Text('Profile Page ${widget.userName}'),
          onPressed: () {
            showDialWidget();
          },
        ),
      ),
    );
  }
}
