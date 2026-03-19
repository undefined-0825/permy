from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class BillingVerifyInput:
    platform: str
    product_id: str
    purchase_token: str


@dataclass(frozen=True)
class BillingVerifyResult:
    verified: bool


class BillingVerifier:
    """課金検証の抽象。将来 Google Play Developer API 実装へ差し替える。"""

    async def verify(self, payload: BillingVerifyInput) -> BillingVerifyResult:
        raise NotImplementedError


class MockBillingVerifier(BillingVerifier):
    """現行の mock 検証。構造だけ固定し、将来実装へ差し替えやすくする。"""

    async def verify(self, payload: BillingVerifyInput) -> BillingVerifyResult:
        # 現在は token の存在のみを最低条件として検証成功扱いにする。
        ok = bool(payload.purchase_token.strip())
        return BillingVerifyResult(verified=ok)
