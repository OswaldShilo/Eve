import 'package:eve_app/features/mascot/eve_rig_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EveRigGeometry body shell', () {
    test('bodyMainShell is a closed path whose fill contains the visual center '
        'and excludes a point clearly outside the pomegranate silhouette', () {
      final path = EveRigGeometry.bodyMainShell();
      // Body shell spans roughly x:20-180, y:44-194 (mockv4.html:1177). Center ~ (100,119).
      expect(path.contains(const Offset(100, 119)), isTrue);
      expect(path.contains(const Offset(0, 0)), isFalse);
      expect(path.contains(const Offset(199, 219)), isFalse);
    });

    test('bodyOutline is larger than bodyMainShell (it is the underlying dark '
        'silhouette drawn first, per mockv4.html:1176-1177)', () {
      final outline = EveRigGeometry.bodyOutline().getBounds();
      final shell = EveRigGeometry.bodyMainShell().getBounds();
      expect(outline.width, greaterThan(shell.width));
      expect(outline.height, greaterThan(shell.height));
    });
  });

  group('EveRigGeometry crown', () {
    test('crownBackLeft contains a point inside its triangular wedge and '
        'excludes the mascot body center (mockv4.html:1229)', () {
      final path = EveRigGeometry.crownBackLeft();
      // Wedge runs roughly between (68,44), (60,26)-ish control, (92,44) tip area.
      expect(path.contains(const Offset(74, 35)), isTrue);
      expect(path.contains(const Offset(100, 119)), isFalse);
    });

    test('all five crown pieces exist and are non-empty paths', () {
      final pieces = [
        EveRigGeometry.crownBackLeft(),
        EveRigGeometry.crownBackRight(),
        EveRigGeometry.crownFrontLeft(),
        EveRigGeometry.crownFrontRight(),
        EveRigGeometry.crownFrontCenter(),
      ];
      for (final p in pieces) {
        expect(p.getBounds().isEmpty, isFalse);
      }
    });
  });

  group('EveRigGeometry seed rows', () {
    test('row counts match the mock (1 seed row = 3 nodes, rows 2/3 = 2 and 3 nodes)', () {
      expect(EveRigGeometry.seedRow1().nodes.length, 3);
      expect(EveRigGeometry.seedRow2().nodes.length, 2);
      expect(EveRigGeometry.seedRow3().nodes.length, 3);
    });

    test('rows 2 and 3 carry the baked-in rest scale/translate from mockv4.html:1200,1211', () {
      expect(EveRigGeometry.seedRow2().restScale, 0.82);
      expect(EveRigGeometry.seedRow2().restTranslate, const Offset(0, -10));
      expect(EveRigGeometry.seedRow3().restScale, 0.82);
      expect(EveRigGeometry.seedRow3().restTranslate, const Offset(0, -14));
      expect(EveRigGeometry.seedRow1().restScale, 1.0);
    });
  });

  group('EveRigGeometry eyes and eyelids', () {
    test('eyelidRect resolves the correct absolute x for each eye (mockv4.html:1259,1271)', () {
      final left = EveRigGeometry.eyelidRect(EveRigGeometry.eyeCenterLeft, -34);
      final right = EveRigGeometry.eyelidRect(EveRigGeometry.eyeCenterRight, -34);
      expect(left.left, 50);
      expect(right.left, 114);
      expect(left.top, 51); // 85 + (-34)
      expect(left.width, 36);
      expect(left.height, 34);
    });

    test('eyelidRect at translateY=0 sits over the eye socket (closed/blink state)', () {
      final rect = EveRigGeometry.eyelidRect(EveRigGeometry.eyeCenterLeft, 0);
      final socket = EveRigGeometry.eyeSocketRect(EveRigGeometry.eyeCenterLeft);
      expect(rect.overlaps(socket), isTrue);
    });
  });

  group('EvePeelStage.fromPercent', () {
    test('below 35 percent: flat crown, only row 1 implied visible', () {
      final stage = EvePeelStage.fromPercent(10);
      expect(stage.crownScale, 1.0);
      expect(stage.crownRotationDegrees, 0);
      expect(stage.seedRow2Visible, isFalse);
      expect(stage.seedRow3Visible, isFalse);
    });

    test('35 to just under 70: crown scale 1.08, rotate -4, row 2 visible, row 3 not', () {
      final stage = EvePeelStage.fromPercent(35);
      expect(stage.crownScale, 1.08);
      expect(stage.crownRotationDegrees, -4);
      expect(stage.seedRow2Visible, isTrue);
      expect(stage.seedRow3Visible, isFalse);

      final justBelow70 = EvePeelStage.fromPercent(69.999);
      expect(justBelow70.crownScale, 1.08);
    });

    test('70 and above: crown scale 1.15, rotate -8, both rows visible', () {
      final stage = EvePeelStage.fromPercent(70);
      expect(stage.crownScale, 1.15);
      expect(stage.crownRotationDegrees, -8);
      expect(stage.seedRow2Visible, isTrue);
      expect(stage.seedRow3Visible, isTrue);
    });
  });

  group('EveRigGeometry arms', () {
    test('arm origins match mockv4.html transform-origin attributes (1236, 1240)', () {
      expect(EveRigGeometry.armLeftOrigin, const Offset(34, 135));
      expect(EveRigGeometry.armRightOrigin, const Offset(166, 135));
      expect(EveRigGeometry.armLeft().getBounds().isEmpty, isFalse);
      expect(EveRigGeometry.armRight().getBounds().isEmpty, isFalse);
    });
  });
}
