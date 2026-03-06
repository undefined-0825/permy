#診断選択肢画像フォルダ

## 用途
このフォルダは、ペルソナ診断画面（DiagnosisScreen）の各選択肢に表示する画像を格納します。

## 仕様
- **対象画面**: DiagnosisScreen（診断画面）
- **想定枚数**: 20-30枚
- **表示サイズ**: 40x40px（現在の実装）
- **推奨作成サイズ**: **240x240px**
  - 高解像度デバイス対応（@3x: 120x120px）
  - 将来的なデザイン調整（拡大）に対応
  - 画像劣化を防ぐため、表示サイズの3-6倍で作成
- **形式**: PNG（透過対応推奨）
- **命名規則**: 選択肢IDに対応したファイル名（例: `choice_stability.png`）

## 実装状態
- **Phase 1（現在）**: プレースホルダー（Icon）で 40x40px 表示中
- **Phase 2（今後）**: 実際の画像に差し替え予定（Image.asset で表示）

## 画像サイズの考え方
- Flutter は自動的に解像度に応じた画像を選択
- 240x240px で作成すれば、以下に対応可能：
  - **現在**: 40x40px 表示 → @3x デバイスで綺麗に表示
  - **将来**: 60-80px に拡大しても劣化なし
  
## 参照
- 仕様: `docs/spec/31_frontend_impl/frontend_impl.md` セクション 7.2
- コード: `frontend/lib/src/presentation/diagnosis_screen.dart` (L257-271: 40x40px Container)
- 診断仕様: `docs/spec/10_product/persona_diagnosis.md`
