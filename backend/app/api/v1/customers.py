from __future__ import annotations

import datetime as dt

from fastapi import APIRouter, Depends, Query
from sqlalchemy import and_, delete, desc, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_db
from app.errors import err
from app.models import Customer, CustomerEvent, CustomerTag, CustomerVisitLog
from app.schemas import (
    CustomerCreateRequest,
    CustomerDetailResponse,
    CustomerEventCreateRequest,
    CustomerEventResponse,
    CustomerResponse,
    CustomerTagReplaceRequest,
    CustomerTagResponse,
    CustomerUpdateRequest,
    CustomerVisitLogCreateRequest,
    CustomerVisitLogResponse,
)
from app.security import AuthContext, get_auth_context

router = APIRouter()


def _require_premium(auth: AuthContext) -> None:
    if auth.feature_tier != "premium":
        raise err("PLAN_REQUIRED", "Premiumプラン専用機能です", status_code=403)


def _to_iso(value: dt.datetime | None) -> str | None:
    return value.isoformat() if value else None


def _to_customer_response(row: Customer) -> CustomerResponse:
    return CustomerResponse(
        customer_id=row.customer_id,
        display_name=row.display_name,
        nickname=row.nickname,
        call_name=row.call_name,
        area_tag=row.area_tag,
        age_range=row.age_range,
        job_tag=row.job_tag,
        relationship_stage=row.relationship_stage,
        visit_frequency_tag=row.visit_frequency_tag,
        drink_style_tag=row.drink_style_tag,
        last_visit_at=_to_iso(row.last_visit_at),
        last_contact_at=_to_iso(row.last_contact_at),
        memo_summary=row.memo_summary,
        is_archived=row.is_archived,
        created_at=row.created_at.isoformat(),
        updated_at=row.updated_at.isoformat(),
    )


def _to_tag_response(row: CustomerTag) -> CustomerTagResponse:
    return CustomerTagResponse(tag_id=row.tag_id, category=row.category, value=row.value)


def _to_visit_log_response(row: CustomerVisitLog) -> CustomerVisitLogResponse:
    return CustomerVisitLogResponse(
        visit_log_id=row.visit_log_id,
        customer_id=row.customer_id,
        visited_on=row.visited_on.isoformat(),
        visit_type=row.visit_type,
        stay_minutes=row.stay_minutes,
        spend_level=row.spend_level,
        drink_amount_tag=row.drink_amount_tag,
        mood_tag=row.mood_tag,
        memo_short=row.memo_short,
        created_at=row.created_at.isoformat(),
    )


def _to_event_response(row: CustomerEvent) -> CustomerEventResponse:
    return CustomerEventResponse(
        event_id=row.event_id,
        customer_id=row.customer_id,
        event_type=row.event_type,
        event_date=row.event_date.isoformat(),
        title=row.title,
        note=row.note,
        remind_days_before=row.remind_days_before,
        is_active=row.is_active,
        created_at=row.created_at.isoformat(),
    )


async def _find_customer_or_404(db: AsyncSession, user_id: str, customer_id: str) -> Customer:
    row = await db.execute(
        select(Customer).where(and_(Customer.customer_id == customer_id, Customer.user_id == user_id))
    )
    customer = row.scalar_one_or_none()
    if not customer:
        raise err("NOT_FOUND", "顧客が見つかりません", status_code=404)
    return customer


def _parse_datetime_or_422(value: str | None, field_name: str) -> dt.datetime | None:
    if value is None:
        return None
    raw = value.strip()
    if not raw:
        return None
    try:
        return dt.datetime.fromisoformat(raw)
    except ValueError as ex:
        raise err("VALIDATION_FAILED", f"{field_name} はISO日時で指定してください", status_code=422) from ex


def _parse_date_or_422(value: str, field_name: str) -> dt.date:
    try:
        return dt.date.fromisoformat(value)
    except ValueError as ex:
        raise err("VALIDATION_FAILED", f"{field_name} はYYYY-MM-DD形式で指定してください", status_code=422) from ex


@router.get("/customers", response_model=list[CustomerResponse])
async def list_customers(
    q: str | None = Query(default=None, max_length=64),
    include_archived: bool = Query(default=False),
    db: AsyncSession = Depends(get_db),
    auth: AuthContext = Depends(get_auth_context),
):
    _require_premium(auth)

    stmt = select(Customer).where(Customer.user_id == auth.user_id)
    if not include_archived:
        stmt = stmt.where(Customer.is_archived.is_(False))

    if q and q.strip():
        keyword = q.strip().lower()
        pattern = f"%{keyword}%"
        tag_exists = (
            select(CustomerTag.tag_id)
            .where(
                and_(
                    CustomerTag.user_id == auth.user_id,
                    CustomerTag.customer_id == Customer.customer_id,
                    func.lower(CustomerTag.value).like(pattern),
                )
            )
            .exists()
        )
        visit_exists = (
            select(CustomerVisitLog.visit_log_id)
            .where(
                and_(
                    CustomerVisitLog.user_id == auth.user_id,
                    CustomerVisitLog.customer_id == Customer.customer_id,
                    func.lower(func.coalesce(CustomerVisitLog.memo_short, "")).like(pattern),
                )
            )
            .exists()
        )
        event_exists = (
            select(CustomerEvent.event_id)
            .where(
                and_(
                    CustomerEvent.user_id == auth.user_id,
                    CustomerEvent.customer_id == Customer.customer_id,
                    func.lower(CustomerEvent.title).like(pattern),
                )
            )
            .exists()
        )

        stmt = stmt.where(
            or_(
                func.lower(Customer.display_name).like(pattern),
                func.lower(func.coalesce(Customer.nickname, "")).like(pattern),
                func.lower(func.coalesce(Customer.call_name, "")).like(pattern),
                func.lower(func.coalesce(Customer.area_tag, "")).like(pattern),
                func.lower(func.coalesce(Customer.job_tag, "")).like(pattern),
                func.lower(func.coalesce(Customer.memo_summary, "")).like(pattern),
                tag_exists,
                visit_exists,
                event_exists,
            )
        )

    stmt = stmt.order_by(desc(Customer.updated_at)).limit(200)
    rows = (await db.execute(stmt)).scalars().all()
    return [_to_customer_response(row) for row in rows]


@router.post("/customers", response_model=CustomerResponse)
async def create_customer(
    req: CustomerCreateRequest,
    db: AsyncSession = Depends(get_db),
    auth: AuthContext = Depends(get_auth_context),
):
    _require_premium(auth)

    now = dt.datetime.now(dt.timezone.utc)
    row = Customer(
        user_id=auth.user_id,
        display_name=req.display_name.strip(),
        nickname=req.nickname,
        call_name=req.call_name,
        area_tag=req.area_tag,
        age_range=req.age_range,
        job_tag=req.job_tag,
        relationship_stage=req.relationship_stage,
        visit_frequency_tag=req.visit_frequency_tag,
        drink_style_tag=req.drink_style_tag,
        last_visit_at=_parse_datetime_or_422(req.last_visit_at, "last_visit_at"),
        last_contact_at=_parse_datetime_or_422(req.last_contact_at, "last_contact_at"),
        memo_summary=req.memo_summary,
        is_archived=req.is_archived,
        created_at=now,
        updated_at=now,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return _to_customer_response(row)


@router.get("/customers/{customer_id}", response_model=CustomerDetailResponse)
async def get_customer(
    customer_id: str,
    db: AsyncSession = Depends(get_db),
    auth: AuthContext = Depends(get_auth_context),
):
    _require_premium(auth)
    customer = await _find_customer_or_404(db, auth.user_id, customer_id)

    tags = (
        await db.execute(
            select(CustomerTag)
            .where(and_(CustomerTag.user_id == auth.user_id, CustomerTag.customer_id == customer_id))
            .order_by(CustomerTag.created_at.desc())
        )
    ).scalars().all()
    visit_logs = (
        await db.execute(
            select(CustomerVisitLog)
            .where(and_(CustomerVisitLog.user_id == auth.user_id, CustomerVisitLog.customer_id == customer_id))
            .order_by(CustomerVisitLog.visited_on.desc(), CustomerVisitLog.created_at.desc())
            .limit(20)
        )
    ).scalars().all()
    events = (
        await db.execute(
            select(CustomerEvent)
            .where(and_(CustomerEvent.user_id == auth.user_id, CustomerEvent.customer_id == customer_id))
            .order_by(CustomerEvent.event_date.asc(), CustomerEvent.created_at.desc())
            .limit(20)
        )
    ).scalars().all()

    return CustomerDetailResponse(
        customer=_to_customer_response(customer),
        tags=[_to_tag_response(tag) for tag in tags],
        visit_logs=[_to_visit_log_response(log) for log in visit_logs],
        events=[_to_event_response(event) for event in events],
    )


@router.put("/customers/{customer_id}", response_model=CustomerResponse)
async def update_customer(
    customer_id: str,
    req: CustomerUpdateRequest,
    db: AsyncSession = Depends(get_db),
    auth: AuthContext = Depends(get_auth_context),
):
    _require_premium(auth)
    row = await _find_customer_or_404(db, auth.user_id, customer_id)

    data = req.model_dump(exclude_unset=True)
    if "display_name" in data:
        row.display_name = (req.display_name or "").strip() or row.display_name
    if "nickname" in data:
        row.nickname = req.nickname
    if "call_name" in data:
        row.call_name = req.call_name
    if "area_tag" in data:
        row.area_tag = req.area_tag
    if "age_range" in data:
        row.age_range = req.age_range
    if "job_tag" in data:
        row.job_tag = req.job_tag
    if "relationship_stage" in data:
        row.relationship_stage = req.relationship_stage
    if "visit_frequency_tag" in data:
        row.visit_frequency_tag = req.visit_frequency_tag
    if "drink_style_tag" in data:
        row.drink_style_tag = req.drink_style_tag
    if "last_visit_at" in data:
        row.last_visit_at = _parse_datetime_or_422(req.last_visit_at, "last_visit_at")
    if "last_contact_at" in data:
        row.last_contact_at = _parse_datetime_or_422(req.last_contact_at, "last_contact_at")
    if "memo_summary" in data:
        row.memo_summary = req.memo_summary
    if "is_archived" in data:
        row.is_archived = bool(req.is_archived)

    row.updated_at = dt.datetime.now(dt.timezone.utc)

    await db.commit()
    await db.refresh(row)
    return _to_customer_response(row)


@router.put("/customers/{customer_id}/tags", response_model=list[CustomerTagResponse])
async def replace_customer_tags(
    customer_id: str,
    req: CustomerTagReplaceRequest,
    db: AsyncSession = Depends(get_db),
    auth: AuthContext = Depends(get_auth_context),
):
    _require_premium(auth)
    customer = await _find_customer_or_404(db, auth.user_id, customer_id)

    await db.execute(
        delete(CustomerTag).where(and_(CustomerTag.user_id == auth.user_id, CustomerTag.customer_id == customer_id))
    )

    now = dt.datetime.now(dt.timezone.utc)
    rows: list[CustomerTag] = []
    for item in req.tags:
        row = CustomerTag(
            user_id=auth.user_id,
            customer_id=customer_id,
            category=item.category,
            value=item.value.strip(),
            created_at=now,
        )
        db.add(row)
        rows.append(row)

    customer.updated_at = now
    await db.commit()

    return [_to_tag_response(row) for row in rows]


@router.post("/customers/{customer_id}/visit-logs", response_model=CustomerVisitLogResponse)
async def create_customer_visit_log(
    customer_id: str,
    req: CustomerVisitLogCreateRequest,
    db: AsyncSession = Depends(get_db),
    auth: AuthContext = Depends(get_auth_context),
):
    _require_premium(auth)
    customer = await _find_customer_or_404(db, auth.user_id, customer_id)

    now = dt.datetime.now(dt.timezone.utc)
    visited_on = _parse_date_or_422(req.visited_on, "visited_on")
    row = CustomerVisitLog(
        user_id=auth.user_id,
        customer_id=customer_id,
        visited_on=visited_on,
        visit_type=req.visit_type,
        stay_minutes=req.stay_minutes,
        spend_level=req.spend_level,
        drink_amount_tag=req.drink_amount_tag,
        mood_tag=req.mood_tag,
        memo_short=req.memo_short,
        created_at=now,
    )
    db.add(row)

    customer.last_visit_at = dt.datetime.combine(visited_on, dt.time.min, tzinfo=dt.timezone.utc)
    customer.updated_at = now

    await db.commit()
    await db.refresh(row)
    return _to_visit_log_response(row)


@router.post("/customers/{customer_id}/events", response_model=CustomerEventResponse)
async def create_customer_event(
    customer_id: str,
    req: CustomerEventCreateRequest,
    db: AsyncSession = Depends(get_db),
    auth: AuthContext = Depends(get_auth_context),
):
    _require_premium(auth)
    customer = await _find_customer_or_404(db, auth.user_id, customer_id)

    now = dt.datetime.now(dt.timezone.utc)
    row = CustomerEvent(
        user_id=auth.user_id,
        customer_id=customer_id,
        event_type=req.event_type,
        event_date=_parse_date_or_422(req.event_date, "event_date"),
        title=req.title.strip(),
        note=req.note,
        remind_days_before=req.remind_days_before,
        is_active=req.is_active,
        created_at=now,
    )
    db.add(row)
    customer.updated_at = now

    await db.commit()
    await db.refresh(row)
    return _to_event_response(row)
