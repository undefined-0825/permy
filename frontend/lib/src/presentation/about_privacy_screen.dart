import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AboutPrivacyScreen extends StatelessWidget {
  const AboutPrivacyScreen({super.key});

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
                  const Text('このアプリについて'),
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
                    // Permyについて
                    const Text(
                      'Permyについて',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Permyはあなたの分身、黒猫のぼく。'
                      'LINEの生のトーク履歴をもらって、返信案を作ります。'
                      'あなたの「返信したくない…」が「返信できた」に変わるまで、ぼくは手伝い続けます。',
                      style: TextStyle(fontSize: 14, height: 1.6),
                    ),
                    const SizedBox(height: 32),

                    // プライバシーとセキュリティ
                    const Text(
                      'プライバシーとセキュリティ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '本文を保存しません',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'あなたがLINEから送ってくれたトーク履歴、ぼくが作った返信案。'
                      'これらの本文内容は、ぼくのサーバに保存しません。'
                      'ぼくはあなたのスマホの中だけで読み取り、毎回新しく返信案を考えます。',
                      style: TextStyle(fontSize: 14, height: 1.6),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '送信はあなたが決める',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ぼくが作った返信案は自動では送られぬ。'
                      'あなたがコピーして、あなた自身がLINEで送ります。'
                      'つまり責任はあなたにある。ぼくはあくまで分身、手伝い役です。',
                      style: TextStyle(fontSize: 14, height: 1.6),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'NG設定は端末に同期',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '「ぼくが返信に入れちゃダメな言葉」「避けるべき文体」は、'
                      'あなたのスマホの設定画面で変えられます。'
                      'ぼくはそれを見ながら返信案を考えることで、あなたの価値観を守ります。',
                      style: TextStyle(fontSize: 14, height: 1.6),
                    ),
                    const SizedBox(height: 32),

                    // 連絡先
                    const Text(
                      'お問い合わせ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ご意見・ご質問・不具合報告は、下記までお願いします。',
                      style: TextStyle(fontSize: 14, height: 1.6),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF).withOpacity(0.9),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.mail_outline, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                // メールアプリ起動
                                // TODO: URLランチャー実装
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'support@permy.jp にメールしてください',
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                'support@permy.jp',
                                style: TextStyle(color: Color(0xFF3B82F6)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 発行者情報
                    const Text(
                      '発行者',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '隙間産業ラボ 中野家',
                      style: TextStyle(fontSize: 14, height: 1.6),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'メール：sukima.lab.nakanoya@gmail.com',
                      style: TextStyle(fontSize: 14, color: Color(0xFF3B82F6)),
                    ),
                    const SizedBox(height: 32),

                    // バージョン情報
                    Center(
                      child: Text(
                        'Version 1.0.0',
                        style: const TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 12,
                        ),
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
}
