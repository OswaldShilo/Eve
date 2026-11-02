import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EveEmotionTable — exact values from setMascotEmotion (mockv4.html:2218-2260)', () {
    test('neutral uses the JS default-branch values, not the template default', () {
      final pose = EveEmotionTable.poses[EveEmotion.neutral]!;
      // Default mouthPath = "M 86,140 Q 100,154 114,140" -> control point y=154.
      expect(pose.mouth.start, const Offset(86, 140));
      expect(pose.mouth.control, const Offset(100, 154));
      expect(pose.mouth.end, const Offset(114, 140));
      expect(pose.mouth.closed, isFalse);
      expect(pose.browLeft.start, const Offset(54, 92));
      expect(pose.browLeft.control, const Offset(68, 88));
      expect(pose.browLeft.end, const Offset(80, 92));
      expect(pose.browRight.control, const Offset(132, 88));
      expect(pose.eyelidRestY, -34);
      expect(pose.fertileGlowOpacity, 0);
    });

    test('caring (covers caring/hug/concerned) matches lines 2227-2231', () {
      final pose = EveEmotionTable.poses[EveEmotion.caring]!;
      expect(pose.mouth.start, const Offset(88, 142));
      expect(pose.mouth.control, const Offset(100, 150));
      expect(pose.mouth.end, const Offset(112, 142));
      expect(pose.browLeft.control, const Offset(68, 94));
      expect(pose.browRight.start, const Offset(120, 91));
      expect(pose.eyelidRestY, -28);
    });

    test('warm (covers warm/happy/positive) is a closed mouth path per lines 2232-2236', () {
      final pose = EveEmotionTable.poses[EveEmotion.warm]!;
      expect(pose.mouth.start, const Offset(84, 138));
      expect(pose.mouth.control, const Offset(100, 162));
      expect(pose.mouth.end, const Offset(116, 138));
      expect(pose.mouth.closed, isTrue);
      expect(pose.eyelidRestY, -34);
    });

    test('hype matches lines 2237-2241', () {
      final pose = EveEmotionTable.poses[EveEmotion.hype]!;
      expect(pose.mouth.control, const Offset(100, 168));
      expect(pose.mouth.closed, isTrue);
      expect(pose.browLeft.control, const Offset(68, 78));
    });

    test('sassy matches lines 2242-2246', () {
      final pose = EveEmotionTable.poses[EveEmotion.sassy]!;
      expect(pose.mouth.control, const Offset(100, 138));
      expect(pose.mouth.closed, isFalse);
      expect(pose.eyelidRestY, -32);
      expect(pose.browRight.start, const Offset(120, 92));
    });

    test('fertile keeps neutral brows/eyelid but a distinct mouth control-y '
        'of 156 (not 154) and 0.8 fertile-glow opacity, per lines 2247-2250', () {
      final pose = EveEmotionTable.poses[EveEmotion.fertile]!;
      expect(pose.mouth.control, const Offset(100, 156));
      expect(pose.browLeft, EveEmotionTable.poses[EveEmotion.neutral]!.browLeft);
      expect(pose.eyelidRestY, -34);
      expect(pose.fertileGlowOpacity, 0.8);
    });

    test('all 6 EveEmotion values have a table entry', () {
      for (final e in EveEmotion.values) {
        expect(EveEmotionTable.poses.containsKey(e), isTrue, reason: '$e missing from table');
      }
    });
  });

  group('shape lerp', () {
    test('EveBrowShape.lerp at t=0 and t=1 returns the endpoints exactly', () {
      const a = EveBrowShape(Offset(0, 0), Offset(1, 1), Offset(2, 2));
      const b = EveBrowShape(Offset(10, 10), Offset(11, 11), Offset(12, 12));
      expect(EveBrowShape.lerp(a, b, 0).start, a.start);
      expect(EveBrowShape.lerp(a, b, 1).start, b.start);
      expect(EveBrowShape.lerp(a, b, 0.5).start, const Offset(5, 5));
    });

    test('EveMouthShape.lerp snaps `closed` at the t=0.5 boundary', () {
      const a = EveMouthShape(Offset(0, 0), Offset(1, 1), Offset(2, 2), closed: false);
      const b = EveMouthShape(Offset(10, 10), Offset(11, 11), Offset(12, 12), closed: true);
      expect(EveMouthShape.lerp(a, b, 0.49).closed, isFalse);
      expect(EveMouthShape.lerp(a, b, 0.5).closed, isTrue);
    });

    test('EveEmotionPose.lerp interpolates fertileGlowOpacity and eyelidRestY', () {
      final a = EveEmotionTable.poses[EveEmotion.neutral]!;
      final b = EveEmotionTable.poses[EveEmotion.fertile]!;
      final mid = EveEmotionPose.lerp(a, b, 0.5);
      expect(mid.fertileGlowOpacity, closeTo(0.4, 0.001));
    });
  });
}
