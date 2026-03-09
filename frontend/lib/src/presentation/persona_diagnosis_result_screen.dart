import 'package:flutter/material.dart';

import '../domain/persona_type_helper.dart';

class PersonaDiagnosisResultScreen extends StatelessWidget {
  const PersonaDiagnosisResultScreen({
    required this.trueType,
    required this.nightType,
    this.assertiveness = 50,
    this.warmth = 50,
    this.riskGuard = 50,
    super.key,
  });

  final String trueType;
  final String nightType;
  final int assertiveness;
  final int warmth;
  final int riskGuard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8D4F8), // 淡いパープル
              Color(0xFFFCE4EC), // 淡いピンク
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/icons/permy_icon.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  const Text('あなたのペルソナ'),
                ],
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '普段の自分',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PersonaTypeCard(
                      typeName: getTrueSelfTypeName(trueType),
                      description: _getTrueTypeDescription(trueType),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '夜の私',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PersonaTypeCard(
                      typeName: getNightSelfTypeName(nightType),
                      description: _getNightTypeDescription(nightType),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'スタイルスコア',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _StyleScoreRow(label: '主張度', score: assertiveness),
                    const SizedBox(height: 12),
                    _StyleScoreRow(label: '温かみ', score: warmth),
                    const SizedBox(height: 12),
                    _StyleScoreRow(label: 'リスク回避', score: riskGuard),
                    const SizedBox(height: 32),
                    const Text(
                      'これらのペルソナは、あなたの返信スタイルを決める大事な指標。'
                      'ときどき見返して、「今のぼくはこう考えてるんだ」って確認してみてね。',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTrueTypeDescription(String type) {
    switch (type) {
      case 'Stability':
        return 'バランスを大事にする。'
            '無理のない生活を心がけ、'
            'まずは安定から。';
      case 'Independence':
        return '自分のペースを守る。'
            '誰かに縛られず、'
            '自分の判断を信じる。';
      case 'Approval':
        return '人の評価を大事にする。'
            '信頼を集めることが喜び。'
            'その分相手との距離が近い。';
      case 'Realism':
        return '現実的に考える。'
            '長期的な得を見える人。'
            '堅実さが武器。';
      case 'Romance':
        return '感情を大事にする。'
            '気持ちが満たされることが優先。'
            'その直感は案外正しい。';
      default:
        return 'ペルソナ種別が不明です。';
    }
  }

  String _getNightTypeDescription(String type) {
    switch (type) {
      case 'VisitPush':
        return '次のお約束を大事にする。'
            '関係を続けることが目標。'
            'その誠実さが信頼を呼ぶ。';
      case 'Heal':
        return '相手を癒したい。'
            'そっと寄り添うのが得意。'
            'その優しさが人を呼ぶ。';
      case 'LittleDevil':
        return '駆け引きを楽しむ。'
            '軽やかなテンポが自分らしい。'
            'その遊び心が魅力。';
      case 'BigClient':
        return '大事な人を見極める。'
            '重点的に寄せることを選ぶ。'
            'その戦略眼が効く。';
      case 'Balance':
        return '全体のバランスを見る。'
            '状況に合わせて柔軟に対応。'
            'その臨機応変さが強み。';
      default:
        return 'ペルソナ種別が不明です。';
    }
  }
}

class _PersonaTypeCard extends StatelessWidget {
  const _PersonaTypeCard({required this.typeName, required this.description});

  final String typeName;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF).withOpacity(0.9),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            typeName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 12),
          Text(description, style: const TextStyle(fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }
}

class _StyleScoreRow extends StatelessWidget {
  const _StyleScoreRow({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 8,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(score)),
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(int score) {
    if (score < 30) {
      return const Color(0xFFF97316);
    } else if (score < 70) {
      return const Color(0xFF3B82F6);
    } else {
      return const Color(0xFF10B981);
    }
  }
}
