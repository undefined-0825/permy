import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from app.redis_client import _MemoryRedis, _ResilientRedis


@pytest.mark.asyncio
async def test_resilient_redis_fallback_on_get_error():
    """
    Redis クライアント get() がエラー時、メモリ実装へフォールバック
    """
    fallback = _MemoryRedis()
    primary_mock = AsyncMock()
    primary_mock.get.side_effect = ConnectionError("Redis connection failed")

    resilient = _ResilientRedis(primary=primary_mock, fallback=fallback)

    # 初回は primary を試す → エラー → fallback へ自動切替
    result = await resilient.get("test_key")
    assert result is None  # fallback のメモリにはまだ key がない

    # 以降は primary を使わない（フォールバック状態）
    assert resilient._primary is None


@pytest.mark.asyncio
async def test_resilient_redis_fallback_on_set_error():
    """
    Redis クライアント set() がエラー時、メモリ実装へフォールバック
    """
    fallback = _MemoryRedis()
    primary_mock = AsyncMock()
    primary_mock.set.side_effect = ConnectionError("Redis unavailable")

    resilient = _ResilientRedis(primary=primary_mock, fallback=fallback)

    # set → エラー → fallback へ
    result = await resilient.set("key1", "value1", ex=3600)
    assert result is True  # fallback の set は成功

    # get → primary なし (fallback のみ) → 値あり
    value = await resilient.get("key1")
    assert value == "value1"


@pytest.mark.asyncio
async def test_resilient_redis_fallback_on_incr_error():
    """
    Redis クライアント incr() がエラー時、メモリ実装へフォールバック
    """
    fallback = _MemoryRedis()
    primary_mock = AsyncMock()
    primary_mock.incr.side_effect = RuntimeError("Redis error")

    resilient = _ResilientRedis(primary=primary_mock, fallback=fallback)

    # incr → エラー → fallback
    count1 = await resilient.incr("counter")
    assert count1 == 1

    count2 = await resilient.incr("counter")
    assert count2 == 2


@pytest.mark.asyncio
async def test_resilient_redis_fallback_on_sadd_error():
    """
    Redis クライアント sadd/smembers がエラー時、メモリ実装へフォールバック
    """
    fallback = _MemoryRedis()
    primary_mock = AsyncMock()
    primary_mock.sadd.side_effect = ConnectionError("Redis down")

    resilient = _ResilientRedis(primary=primary_mock, fallback=fallback)

    # sadd → エラー → fallback
    result = await resilient.sadd("myset", "item1")
    assert result == 1

    # smembers → fallback のみ
    members = await resilient.smembers("myset")
    assert "item1" in members


@pytest.mark.asyncio
async def test_resilient_redis_pipeline_fallback():
    """
    Redis パイプライン実行が失敗時、メモリ実装へフォールバック
    """
    fallback = _MemoryRedis()
    primary_mock = MagicMock()
    pipe_mock = AsyncMock()
    pipe_mock.execute.side_effect = ConnectionError("Pipeline failed")
    primary_mock.pipeline.return_value = pipe_mock

    resilient = _ResilientRedis(primary=primary_mock, fallback=fallback)

    # パイプライン構築と実行
    pipe = resilient.pipeline()
    pipe.incr("key1")
    pipe.ttl("key1")
    results = await pipe.execute()

    # incr のみ実行 (0番目), ttl は実行されない
    assert isinstance(results, list)
    assert len(results) == 2
    assert results[0] == 1  # incr の結果


@pytest.mark.asyncio
async def test_resilient_redis_continues_fallback_after_switch():
    """
    一度フォールバックしたら、その後のコマンドもメモリで実行
    """
    fallback = _MemoryRedis()
    primary_mock = AsyncMock()
    primary_mock.set.side_effect = ConnectionError("Always fails")
    primary_mock.get.side_effect = ConnectionError("Always fails")

    resilient = _ResilientRedis(primary=primary_mock, fallback=fallback)

    # 最初の set でエラー → fallback へ
    await resilient.set("key1", "value1")
    assert resilient._primary is None

    # その後の get も primary を呼ばず fallback のみ
    value = await resilient.get("key1")
    assert value == "value1"

    # primary.get() は 1回目の set エラー後は呼ばれない
    # (primary がすでに None なので try ブロックをスキップ)
    assert primary_mock.get.call_count == 0
