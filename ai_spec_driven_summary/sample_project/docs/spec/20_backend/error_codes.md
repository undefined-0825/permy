# error_codes.md — [ProjectName] Backend Error Codes（●●ゼロ運用 / API●●補助）

**Scope:** 本ドキュメントはバックエンドが返却する `error_code` の一覧と意味論を定義する。  
●●（●●/●●）をログ・保存しない運用のため、**障害解析は error_code と request_id 等のメタ情報で成立**させる。

---

## 0. 共通フォーマット（再掲）
APIのエラーは原則として以下を返す。

```json
{
  "error_code": "AUTH_INVALID",
  "message": "human readable short message",
  "request_id": "optional"
}
```

- `message` は短文（機微情報や●●断片を含めない）。
- `request_id` は任意。●●を含まない識別子のみ。

---

## 1. 命名規約
- すべて **大文字スネークケース**（例：`AUTH_INVALID`）
- 1 error_code は 1 つの主要原因に対応させる（多義にしない）。
- クライアントは `error_code` を主に分岐し、`message` は表示補助に留める。

---

## 2. error_code 一覧（MUST）

### 2.1 認証（Auth）
| error_code | HTTP | 意味 | 典型原因 | クライアント推奨動作 |
|---|---:|---|---|---|
| AUTH_INVALID | 401 | 認証●●ンが無効/期限切れ/欠落 | Authorizationヘッダ不正、●●ン失効 | 再ログイン（匿名再発行）→再試行 |
| AUTH_REQUIRED | 401 | 認証が必要（未●●） | Authorization未付与 | ●●ン付与して再試行 |

※`AUTH_REQUIRED` を使わない場合は `AUTH_INVALID` に統一してもよい（実装側で決めてよい）。

---

### 2.2 ●●検証（Validation）
| error_code | HTTP | 意味 | 典型原因 | クライアント推奨動作 |
|---|---:|---|---|---|
| VALIDATION_ERROR | 400 | リクエスト形式が不正 | 必須フィールド欠落、型不一致、桁数違反 | ●●を修正して再送 |
| UNSUPPORTED_MEDIA_TYPE | 415 | Content-Type不正 | JSON以外 | Content-Typeを修正 |

---

### 2.3 ●●/権限（●● / ●●）
※機能判定は内部 `●●` に基づくが、外部●●では `●●=●●/●●` を返す。

| error_code | HTTP | 意味 | 典型原因 | クライアント推奨動作 |
|---|---:|---|---|---|
| PLAN_REQUIRED | 403 | Pro相当の機能が必要 | ●●ユーザーが●●専用機能を要求 |●● or 設定を戻す |

---

### 2.4 競合（Concurrency / Idempotency）
| error_code | HTTP | 意味 | 典型原因 | クライアント推奨動作 |
|---|---:|---|---|---|
| ETAG_MISMATCH | 409 | If-MatchのETag不一致 | 設定が他で更新済み | GETで再取得→再編集→PUT |
| IDEMPOTENCY_CONFLICT | 409 | 冪等キー競合 | 同一Idempotency-Keyで並行●●など | 少し待って再試行（キーは変えない/方針に従う） |

---

### 2.5 制限（Rate / Usage）
| error_code | HTTP | 意味 | 典型原因 | クライアント推奨動作 |
|---|---:|---|---|---|
| RATE_LIMITED | 429 | レート制限超過 | 短時間の連打、IP制限 | 指定時間待機→再試行（指数バックオフ） |
| DAILY_LIMIT_EXCEEDED | 429 | 日次●●超過 | その日の上限到達 | 翌日まで待機 / Pro誘導（別Spec） |

---

### 2.6 移行（Migration）
| error_code | HTTP | 意味 | 典型原因 | クライアント推奨動作 |
|---|---:|---|---|---|
| MIGRATION_CODE_INVALID | 404 | 移行コードが存在しない/形式不正 | ●●ミス、無効コード | ●●し直し |
| MIGRATION_CODE_EXPIRED | 410 | 移行コード期限切れ | 期限超過 | 再発行を促す |
| MIGRATION_CODE_ALREADY_USED | 409 | 移行コードは使用済み | 既に消費済み | 再発行を促す |
| MIGRATION_RATE_LIMITED | 429 | 移行関連のレート制限 | 試行回数過多 | 待機→再試行 |

---

### 2.7 依存サービス（Upstream / LLM）
| error_code | HTTP | 意味 | 典型原因 | クライアント推奨動作 |
|---|---:|---|---|---|
| UPSTREAM_UNAVAILABLE | 503 | 依存サービスが利用不可 | LLM側障害、ネットワーク | 時間を置いて再試行 |
| UPSTREAM_TIMEOUT | 503 | 依存サービスがタイムアウト | LLM応答遅延 | 時間を置いて再試行 |
| OPENAI_DISABLED | 503 | LLM呼び出し無効化 | CI/安全運用で無効 | 利用不可として扱う（テスト環境表示） |

---

### 2.8 サーバ内部（Internal）
| error_code | HTTP | 意味 | 典型原因 | クライアント推奨動作 |
|---|---:|---|---|---|
| INTERNAL_ERROR | 500 | 想定外の内部エラー | 例外、バグ | request_idを添えて再試行/報告 |
| STORAGE_UNAVAILABLE | 503 | DB/キャッシュ利用不可 | DB停止、接続上限 | 時間を置いて再試行 |

---

## 3. ●●ゼロ運用のための補足（MUST）
- `message` に●●●●・●●●●、またはその断片を含めない。
- ログには request/response body を出さない（error_code、request_id、タイミング等のみ）。
- 障害調査は以下の最小情報で行う：
  - `request_id`（任意）
  - `error_code`
  - 発生時刻（クライアント側でも可）
  - エンドポイント名（/generate 等）

---

## 4. 変更ルール
- error_code の追加は互換破壊ではないが、**意味の変更**は破壊的変更。
- 廃止は原則禁止。必要なら一定期間は別コードへマップして段階移行する。
