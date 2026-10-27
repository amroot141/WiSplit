from decimal import Decimal, ROUND_HALF_UP
from typing import List
from app.schemas import CreateExpenseRequest, CalculatedSplit, SplitType

CENT = Decimal("0.01")


def calculate_splits(request: CreateExpenseRequest) -> List[CalculatedSplit]:
    """
    Computes exact penny-accurate splits for any split type (EQUAL, EXACT, PERCENTAGE, SHARES).
    Guarantees that sum(calculated_splits.amount) == request.amount.
    """
    total_amount = request.amount
    num_splits = len(request.splits)
    calculated: List[CalculatedSplit] = []

    if request.split_type == SplitType.EXACT:
        for s in request.splits:
            calculated.append(
                CalculatedSplit(
                    user_id=s.user_id,
                    amount=s.amount.quantize(CENT, rounding=ROUND_HALF_UP),
                )
            )

    elif request.split_type == SplitType.EQUAL:
        # Divide amount equally, distribute remainder pennies to the first N users
        base_amount = (total_amount / Decimal(num_splits)).quantize(CENT, rounding=ROUND_HALF_UP)
        allocated_total = base_amount * Decimal(num_splits)
        diff = total_amount - allocated_total  # in cents

        for i, s in enumerate(request.splits):
            user_amount = base_amount
            # Adjust penny if there's a discrepancy
            if diff > Decimal("0") and i < int(diff / CENT):
                user_amount += CENT
            elif diff < Decimal("0") and i < int(abs(diff) / CENT):
                user_amount -= CENT

            calculated.append(
                CalculatedSplit(
                    user_id=s.user_id,
                    amount=user_amount,
                )
            )

    elif request.split_type == SplitType.PERCENTAGE:
        running_total = Decimal("0.00")
        for i, s in enumerate(request.splits):
            if i == num_splits - 1:
                # Assign the remaining balance to the last user to eliminate penny rounding mismatch
                user_amount = total_amount - running_total
            else:
                user_amount = (total_amount * (s.percentage / Decimal("100.00"))).quantize(
                    CENT, rounding=ROUND_HALF_UP
                )
                running_total += user_amount

            calculated.append(
                CalculatedSplit(
                    user_id=s.user_id,
                    amount=user_amount,
                    percentage=s.percentage,
                )
            )

    elif request.split_type == SplitType.SHARES:
        total_shares = sum(s.shares for s in request.splits)
        running_total = Decimal("0.00")

        for i, s in enumerate(request.splits):
            if i == num_splits - 1:
                # Assign the remainder balance to the last user to prevent rounding gap
                user_amount = total_amount - running_total
            else:
                user_amount = (total_amount * (s.shares / total_shares)).quantize(
                    CENT, rounding=ROUND_HALF_UP
                )
                running_total += user_amount

            calculated.append(
                CalculatedSplit(
                    user_id=s.user_id,
                    amount=user_amount,
                    shares=s.shares,
                )
            )

    # Final assertion to guarantee financial integrity
    calculated_sum = sum(c.amount for c in calculated)
    if calculated_sum != total_amount:
        # Fallback correction: adjust difference on the first split
        correction = total_amount - calculated_sum
        calculated[0].amount += correction

    return calculated
