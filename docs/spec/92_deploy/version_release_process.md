# version_release_process.md — バージョン更新手順・運用ガイド

本ドキュメントは、Permy アプリケーションの **バージョンアップ時における運用手順** を定義する。  
開発 → テスト → 本番デプロイまでの一連のステップを記載。

---

## 1. 準備（開発フェーズ）

### 1.1 バージョン番号の決定

- 既存バージョン（最新）を確認：`git tag` または `backend/app/config.py` の `app_version` を見る。
- 新バージョンを **セマンティック バージョニング** に従い決定（例: `1.0.0` → `1.1.0`）。

### 1.2 リリースノート作成

- **フォーマット**:
  - `title`（見出し・1 行）: 例「v1.1.0 アップデート」
  - `body`（本文・4096 文字上限）: 例「・新機能 A\n・バグ修正 B\n・パフォーマンス向上」
- Markdown 対応は仕様に応じて（現在は plain text 想定）。
- 社内スプレッドシート / Notion などで草稿作成 → レビュー → 確定。

### 1.3 変更リストの確認

- `git log <prev_version>..HEAD` でコミット一覧を確認。
- バグ修正・機能追加を抽出し、ユーザー向けメッセージに要約。

---

## 2. コンフィグ・ファイル更新

### 2.1 バックエンド設定（config.py）

```python
# backend/app/config.py

app_version: str = "1.1.0"  # 新バージョン
app_min_supported_version: str = "1.0.0"  # 古いバージョン切り捨て時に更新
app_android_store_url: str = "https://play.google.com/store/apps/details?id=..."
app_ios_store_url: str = ""  # iOS ストアURL未設定の例。公開時は App Store URL を設定
```

**判定ロジック:**

- ユーザーが `app_version` より古いバージョンを使用している場合：
  - `installed_version < min_supported_version` → 強制更新
  - `installed_version < app_version` → 任意更新（リリースノート表示）

### 2.2 フロントエンド設定（pubspec.yaml）

```yaml
version: 1.1.0+1  # version+buildNumber（iOS/Android 両対応）
```

**ビルド・リリース方法および環境変数設定は、各プラットフォーム（iOS/Android）側 Spec に委譲。**

---

## 3. DB へリリースノート登録

### 3.1 本番 DB への INSERT（DBA / TL 対応）

**分類**:

- **開発環境** : `./init_db_simple.py` で初期化済み（SQLite）
- **ステージング**: 手動 INSERT（Postgres）
- **本番**: 手動 INSERT（Postgres）

### 3.2 SQL 例

```sql
INSERT INTO app_release_notes (version, title, body, released_at)
VALUES (
  '1.1.0',
  'v1.1.0 アップデート',
  '・新機能：スマート返信提案\n・バグ修正：設定保存の不具合\n・パフォーマンス向上',
  NOW()  -- または CURRENT_TIMESTAMP
);
```

**確認**:
```sql
SELECT * FROM app_release_notes 
WHERE version = '1.1.0';
```

### 3.3 登録タイミング

1. テスト環境（staging）でリリースノート表示確認 → OK
2. 本番デプロイ前に本番 DB へ INSERT
3. サーバー再起動 / デプロイスクリプト実行
4. `GET /api/v1/version` で確認

---

## 4. バックエンド・ビルド & デプロイ

### 4.1 ローカル確認

```bash
cd c:\dev\permy\backend

# テスト実行
python -m pytest tests/test_contract_version.py -v

# ローカルサーバー起動
uvicorn app.main:app --reload
```

### 4.2 Git タグ & コミット

```bash
git add backend/app/config.py
git commit -m "バージョン 1.1.0 へアップデート"
git tag v1.1.0
git push origin main
git push origin v1.1.0
```

### 4.3 Render デプロイ（本番 or staging）

1. **Render Dashboard** にログイン
2. Permy バックエンドサービスを選択
3. 環境変数確認:

   - `APP_VERSION=1.1.0`
   - `APP_MIN_SUPPORTED_VERSION=1.0.0`
   - `DATABASE_URL` (本番接続先)
4. 再デプロイ（Render が自動 or 手動トリガー）
5. デプロイ完了待機（ログ監視）
6. `curl https://<backend_url>/api/v1/version` で確認

**レスポンス例：**
```json
{
  "latest_version": "1.1.0",
  "min_supported_version": "1.0.0",
  "android_store_url": "...",
  "ios_store_url": "",
  "release_note_title": "v1.1.0 アップデート",
  "release_note_body": "・新機能...\n・バグ修正..."
}
```

---

## 5. フロントエンド・ビルド & デプロイ

### 5.1 バージョン番号確認

`pubspec.yaml` の `version: X.Y.Z+N` を確認（バックエンドと同じ `X.Y.Z`）。

### 5.2 ローカルテスト

```bash
cd c:\dev\permy\frontend

# テスト実行
flutter test test/update_notice_test.dart -v

# 実機テスト（デバイス接続）
flutter run -d <device_id> \
  --dart-define=API_BASE_URL=https://permy-backend.onrender.com
```

**画面確認：**

- 起動時に `/api/v1/version` を呼び出し
- リリースノートが表示されるか確認
- 「バージョンアップする」ボタン → Google Play 遷移確認

### 5.3 Android 向けビルド

```bash
flutter build apk --release
# または aab (Google Play)
flutter build appbundle --release
```

**Google Play Console にアップロード:**
1. APK/AAB ファイルをアップロード
2. ビルド番号・リリースノート（UI用）を入力
3. 段階的ロールアウト or 全体公開を選択
4. 公開

### 5.4 iOS 向けビルド

```bash
flutter build ios --release
# または
flutter build ipa --release
```

**App Store Connect にアップロード:**
1. Xcode / `xcode_build_settings.json` から IPA を作成
2. TestFlight へアップロード（テスト）
3. App Store へ申請

**注意：** iOS は `ios_store_url` が未設定のため、App Store リンク設定後に `config.py` を更新する。

---

## 6. バージョンアップ検証・テスト

### 6.1 シナリオ① : 任意アップデート（ユーザー端末 1.0.0 → サーバー 1.1.0）

**前提:**

- `min_supported_version = 1.0.0`（1.0.0 はまだ利用可）
- `latest_version = 1.1.0`

**期待動作:**

- 起動時に任意更新通知画面表示 → 「あとで」か「バージョンアップする」選択可能
- 「バージョンアップする」→ Google Play 再度

### 6.2 シナリオ② : 強制アップデート（ユーザー端末 0.9.0 → サーバー 1.1.0、min_supported_version=1.0.0）

**前提:**

- `min_supported_version = 1.0.0`（0.9.0 は利用不可）

**期待動作:**

- 起動時に強制更新通知画面表示
- 戻る不可（PopScope canPop=false）
- 必ず Google Play へ誘導

### 6.3 確認項目

| 項目 | 確認方法 | 合格基準 |
|-----|--------|--------|
| リリースノート表示 | `GET /api/v1/version` レスポンス | `release_note_title`・`release_note_body` が空でない |
| 任意更新通知 | デバイス `1.0.0` で起動 | 誌画面表示・「あとで」ボタン動作 |
| 強制更新通知 | デバイス `0.9.0` で起動 | 誌画面表示・修復不可・Google Play 遷移 |
| ストア URL | 誌画面から Google Play タップ | Google Play ストア画面開き |
| バージョン比較ロジック | 複数バージョン組み合わせ | セマンティック比較が正確 |

---

## 7. ロールバック手順（緊急時）

### 7.1 バックエンド・ロールバック

```bash
# 旧バージョンのコミットに戻す
git revert <新バージョンコミットハッシュ>
# または
git checkout <旧バージョンハッシュ>

# Render に再デプロイ
# → 環境変数の app_version を前のバージョンへ変更
# → サーバー再起動
```

### 7.2 フロント・ロールバック

- Google Play Console から旧バージョン APK を再度公開
- または、段階的ロールアウトを停止
- ユーザーは前バージョン APK をダウンロード可能な状態に

---

## 8. リリース後・運用フェーズ

### 8.1 定期監視

- `GET /api/v1/version` 応答確認（日次）
- エラーログ監視（DB アクセス失敗等）
- ユーザー報告のバグ・クラッシュ収集

### 8.2 次リリースへの記録

- 本リリースの経験（問題・所要時間等）を内部ドキュメント or Notion へ記録
- 継続的改善に反映

---

## 9. チェックリスト（リリース時）

- [ ] バージョン番号を決定（セマンティック）
- [ ] リリースノート（title・body）完成・レビュー
- [ ] `backend/app/config.py`：app_version, min_supported_version, store URL を更新
- [ ] `frontend/pubspec.yaml`：version を同じ X.Y.Z に更新
- [ ] 本番 DB に `AppReleaseNote` INSERT
- [ ] バックエンド・テスト実行 & 本番デプロイ
- [ ] `GET /api/v1/version` で確認
- [ ] フロント・実機テスト実施
- [ ] Android / iOS ビルド & ストア公開
- [ ] 任意更新・強制更新シナリオをテスト環境で確認
- [ ] Go/No-Go 判定 & リリース承認
- [ ] リリース後・監視開始

---

## Appendix: 環境変数・設定参考値

```env
# .env（本番）
APP_VERSION=1.1.0
APP_MIN_SUPPORTED_VERSION=1.0.0
APP_ANDROID_STORE_URL=https://play.google.com/store/apps/details?id=com.sukimalab.permy
APP_IOS_STORE_URL=
```

```sql
-- app_release_notes テーブル定義（参考）
CREATE TABLE IF NOT EXISTS app_release_notes (
  version VARCHAR(32) PRIMARY KEY,
  title VARCHAR(256) NOT NULL DEFAULT 'バージョンアップのお知らせ',
  body VARCHAR(4096) NOT NULL DEFAULT '',
  released_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

**ドキュメント版**：v1.0  
**最終更新**：2026-03-17  
**レビュー者**：Choby
