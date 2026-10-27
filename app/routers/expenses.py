from decimal import Decimal
from typing import Any, Dict, List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from supabase import Client

from app.config import get_supabase_client
from app.schemas import (
    CreateExpenseRequest,
    ExpenseResponse,
    ExpenseSplitResponse,
)
from app.services.split_calculator import calculate_splits

router = APIRouter(prefix="/groups", tags=["Expenses"])


@router.post(
    "/{group_id}/expenses",
    response_model=ExpenseResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new group expense and insert calculated splits",
)
async def create_group_expense(
    group_id: UUID,
    request: CreateExpenseRequest,
    supabase: Client = Depends(get_supabase_client),
) -> ExpenseResponse:
    """
    Accepts a new group expense, calculates exact penny-accurate splits based on the
    chosen split type (EQUAL, EXACT, PERCENTAGE, SHARES), verifies membership,
    and inserts the expense and splits into Supabase PostgreSQL.
    """
    # 1. Verify group membership for payer and all split participants
    try:
        members_resp = (
            supabase.table("group_members")
            .select("user_id")
            .eq("group_id", str(group_id))
            .execute()
        )
        group_member_ids = {UUID(m["user_id"]) for m in members_resp.data}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error querying group members: {str(e)}",
        )

    if not group_member_ids:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Group '{group_id}' not found or has no registered members.",
        )

    # Ensure payer is in group
    if request.paid_by not in group_member_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Payer '{request.paid_by}' is not a member of group '{group_id}'.",
        )

    # Ensure all split members are in group
    for split_item in request.splits:
        if split_item.user_id not in group_member_ids:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"User '{split_item.user_id}' in split specification is not a member of group '{group_id}'.",
            )

    # 2. Compute exact penny-perfect splits
    calculated_splits = calculate_splits(request)

    # 3. Insert Expense Record
    expense_insert_data = {
        "group_id": str(group_id),
        "paid_by": str(request.paid_by),
        "amount": float(request.amount),
        "currency": request.currency,
        "description": request.description,
        "split_type": request.split_type.value,
    }
    if request.created_at:
        expense_insert_data["created_at"] = request.created_at.isoformat()

    try:
        expense_resp = (
            supabase.table("expenses")
            .insert(expense_insert_data)
            .execute()
        )
        if not expense_resp.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to insert expense record into database.",
            )
        created_expense = expense_resp.data[0]
        expense_id = created_expense["id"]
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error inserting expense: {str(e)}",
        )

    # 4. Insert Expense Splits Records
    splits_insert_data: List[Dict[str, Any]] = []
    for split in calculated_splits:
        split_dict = {
            "expense_id": str(expense_id),
            "user_id": str(split.user_id),
            "amount": float(split.amount),
            "percentage": float(split.percentage) if split.percentage is not None else None,
            "shares": float(split.shares) if split.shares is not None else None,
        }
        if request.created_at:
            split_dict["created_at"] = request.created_at.isoformat()
        splits_insert_data.append(split_dict)

    try:
        splits_resp = (
            supabase.table("expense_splits")
            .insert(splits_insert_data)
            .execute()
        )
        created_splits = splits_resp.data
    except Exception as e:
        # Note: In production PostgreSQL, we can use an RPC/stored procedure to execute both in an atomic transaction
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Expense created but failed to insert splits: {str(e)}",
        )

    # 5. Format and return response
    return ExpenseResponse(
        id=UUID(created_expense["id"]),
        group_id=UUID(created_expense["group_id"]),
        paid_by=UUID(created_expense["paid_by"]),
        amount=Decimal(str(created_expense["amount"])),
        currency=created_expense["currency"],
        description=created_expense["description"],
        split_type=created_expense["split_type"],
        created_at=created_expense["created_at"],
        splits=[
            ExpenseSplitResponse(
                id=UUID(s["id"]),
                expense_id=UUID(s["expense_id"]),
                user_id=UUID(s["user_id"]),
                amount=Decimal(str(s["amount"])),
                percentage=Decimal(str(s["percentage"])) if s.get("percentage") is not None else None,
                shares=Decimal(str(s["shares"])) if s.get("shares") is not None else None,
                created_at=s["created_at"],
            )
            for s in created_splits
        ],
    )
