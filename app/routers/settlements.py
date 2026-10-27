from collections import defaultdict
from decimal import Decimal
from typing import Dict, List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from supabase import Client

from app.config import get_supabase_client
from app.schemas import DebtSettlement
from app.services.settlement import minimize_cash_flow

router = APIRouter(prefix="/groups", tags=["Settlements"])


@router.get(
    "/{group_id}/settlements",
    response_model=List[DebtSettlement],
    status_code=status.HTTP_200_OK,
    summary="Calculate simplified debts for a group using greedy cash flow minimization",
)
async def get_group_settlements(
    group_id: UUID,
    currency: str = Query(default="USD", min_length=3, max_length=3),
    supabase: Client = Depends(get_supabase_client),
) -> List[DebtSettlement]:
    """
    Fetches all historical expenses and splits for a group, calculates net balances
    for each member (total_paid - total_owed), and executes a greedy Max-Heap / Min-Heap
    cash flow minimization algorithm to return the minimal list of debt settlements.
    """
    # 1. Verify group exists
    try:
        group_resp = (
            supabase.table("groups")
            .select("id")
            .eq("id", str(group_id))
            .execute()
        )
        if not group_resp.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Group '{group_id}' not found.",
            )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error checking group existence: {str(e)}",
        )

    # 2. Fetch all expenses with their splits for this group
    try:
        expenses_resp = (
            supabase.table("expenses")
            .select("id, paid_by, amount, currency, expense_splits(user_id, amount)")
            .eq("group_id", str(group_id))
            .execute()
        )
        expenses_data = expenses_resp.data
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error retrieving group expenses from database: {str(e)}",
        )

    if not expenses_data:
        return []

    # 3. Calculate Net Balances per User
    # net_balance = total_paid - total_owed
    net_balances: Dict[UUID, Decimal] = defaultdict(lambda: Decimal("0.00"))

    for exp in expenses_data:
        payer_id = UUID(exp["paid_by"])
        exp_amount = Decimal(str(exp["amount"]))

        # Creditor: paid the total expense amount up front
        net_balances[payer_id] += exp_amount

        # Debtors: owe their individual allocated split amounts
        splits = exp.get("expense_splits", [])
        for sp in splits:
            split_user_id = UUID(sp["user_id"])
            split_amount = Decimal(str(sp["amount"]))
            net_balances[split_user_id] -= split_amount

    # 4. Run Greedy Cash Flow Minimization with Max-Heap/Min-Heap
    settlements = minimize_cash_flow(net_balances=dict(net_balances), currency=currency)

    return settlements
