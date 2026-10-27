import heapq
from decimal import Decimal
from typing import Dict, List
from uuid import UUID

from app.schemas import DebtSettlement

CENT_TOLERANCE = Decimal("0.009")


def minimize_cash_flow(
    net_balances: Dict[UUID, Decimal],
    currency: str = "USD"
) -> List[DebtSettlement]:
    """
    Greedy 'Minimize Cash Flow' Algorithm using Max-Heap & Min-Heap logic.
    
    Given net balances for each user (net = total_paid - total_owed):
      - Positive net balance -> Creditor (should receive money)
      - Negative net balance -> Debtor (owes money)
      - Zero net balance     -> Settled
      
    Uses two heaps to repeatedly match the largest debtor with the largest creditor:
      - debtors_heap (Max-Heap via negative values): pops person owing the largest amount.
      - creditors_heap (Max-Heap via negative values): pops person owed the largest amount.
      
    Returns a minimal list of direct transactions to fully settle group balance.
    Time Complexity: O(N log N) where N is number of group members.
    """
    creditors_heap: List[tuple[Decimal, str]] = []  # (-credit_amount, user_id_str)
    debtors_heap: List[tuple[Decimal, str]] = []    # (-debt_amount, user_id_str)

    # Classify members into creditors and debtors
    for user_id, balance in net_balances.items():
        if balance > CENT_TOLERANCE:
            # Positive balance = Creditor
            # Store negative for max-heap behavior with Python's min-heap heapq
            heapq.heappush(creditors_heap, (-balance, str(user_id)))
        elif balance < -CENT_TOLERANCE:
            # Negative balance = Debtor
            debt_amount = abs(balance)
            heapq.heappush(debtors_heap, (-debt_amount, str(user_id)))

    settlements: List[DebtSettlement] = []

    # Greedily match maximum debtor with maximum creditor
    while creditors_heap and debtors_heap:
        neg_credit, creditor_id_str = heapq.heappop(creditors_heap)
        neg_debt, debtor_id_str = heapq.heappop(debtors_heap)

        credit_amount = -neg_credit
        debt_amount = -neg_debt

        # Settle the minimum of the two amounts
        settle_amount = min(credit_amount, debt_amount)

        # Avoid zero or sub-cent ghost transactions
        if settle_amount > Decimal("0.00"):
            settlements.append(
                DebtSettlement(
                    from_user_id=UUID(debtor_id_str),
                    to_user_id=UUID(creditor_id_str),
                    amount=settle_amount.quantize(Decimal("0.01")),
                    currency=currency,
                )
            )

        # Calculate remainder after this partial/full settlement
        remaining_credit = credit_amount - settle_amount
        remaining_debt = debt_amount - settle_amount

        # If creditor still has remaining balance to receive, push back into creditor heap
        if remaining_credit > CENT_TOLERANCE:
            heapq.heappush(creditors_heap, (-remaining_credit, creditor_id_str))

        # If debtor still has remaining debt to pay, push back into debtor heap
        if remaining_debt > CENT_TOLERANCE:
            heapq.heappush(debtors_heap, (-remaining_debt, debtor_id_str))

    return settlements
