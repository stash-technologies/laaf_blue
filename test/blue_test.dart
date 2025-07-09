/*
import 'package:flutter_test/flutter_test.dart';
import 'package:blue/blue.dart';
import 'package:blue/blue_platform_interface.dart';
import 'package:blue/blue_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';



class MockBluePlatform
    with MockPlatformInterfaceMixin
    implements BluePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final BluePlatform initialPlatform = BluePlatform.instance;

  test('$MethodChannelBlue is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelBlue>());
  });

  test('getPlatformVersion', () async {
    Blue bluePlugin = Blue();
    MockBluePlatform fakePlatform = MockBluePlatform();
    BluePlatform.instance = fakePlatform;

    expect(await bluePlugin.getPlatformVersion(), '42');
  });
} */
