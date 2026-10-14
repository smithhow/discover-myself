import 'package:flutter/material.dart';
import 'services/app_state.dart';
import 'ui/onboarding/pin_screen.dart';
import 'ui/onboarding/profile_select_screen.dart';

Widget app() => MaterialApp(
      title: '发现自我',
      home: PinScreen(onUnlocked: (key) async {}),
      routes: {
        '/profiles': (c) => ProfileSelectScreen(names: const ['我'], onSelect: (i) {}),
      },
    );
