# frontend_impl.md — [ProjectName] フロント実装Spec（Flutter / ●●受信 / ●●非保存 / API整合）

**Scope:** 本ドキュメントはフロントエンドの実装指針を定義する。  
設計は `frontend.*`、バックエンド●●は `api_contract.*` と `error_codes.*` を正とする。

---

## 0. 実装の大原則（MUST）
1) **●●は●●受信のみ**：●●を作らない  
2) **●●非保存**：●●txt●●/●●●●を端末永続化しない（DB/ファイル/キャッシュ/ログ禁止）  
3) **API整合**：`/api/v1` ●●・error_code分岐・ETag/If-Match・Idempotency-Key を厳守  
4) **UX最優先**：待ち時間・失敗時の復帰が分かりやすい。Safe Area/キーボード対応を最初から確定  
5) **依存最小**：●●受信はネイティブ実装（プラグイン●●禁止）

---

## 1. Flutter アーキテクチャ（推奨）
### 1.1 レイヤ
- `presentation`：Widget / Screen / UI State
- `application`：UseCase（Generate/Settings/Migration/Auth）
- `domain`：Model（Settings, Candidate, ApiErrorなど）
- `infrastructure`：API client, storage, platform channels

### 1.2 状態管理
- 既存方針に合わせる（Riverpod/Bloc等の選択は●●ジェクト標準に従う）
- 必須条件：画面遷移・ローディング・エラー表示・リトライを一貫して扱えること

---

## 2. ディレクトリ構成（例）
ここから先は秘密(全900行)
