from datetime import datetime
from decimal import Decimal
from enum import Enum
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


class SplitType(str, Enum):
    EQUAL = "EQUAL"
    EXACT = "EXACT"
    PERCENTAGE = "PERCENTAGE"
    SHARES = "SHARES"


class SplitItemInput(BaseModel):
    user_id: UUID
    amount: Optional[Decimal] = Field(default=None, decimal_places=2, ge=0)
    percentage: Optional[Decimal] = Field(default=None, decimal_places=2, ge=0, le=100)
    shares: Optional[Decimal] = Field(default=None, ge=0)


class CreateExpenseRequest(BaseModel):
    paid_by: UUID
    amount: Decimal = Field(..., gt=0, decimal_places=2, description="Total expense amount")
    currency: str = Field(default="USD", min_length=3, max_length=3)
    description: str = Field(..., min_length=1, max_length=255)
    split_type: SplitType = Field(default=SplitType.EQUAL)
    splits: List[SplitItemInput] = Field(..., min_length=1, description="List of participants to split among")
    created_at: Optional[datetime] = None

    @model_validator(mode="after")
    def validate_splits(self) -> "CreateExpenseRequest":
        # 1. Check for duplicate users in the split list
        user_ids = [s.user_id for s in self.splits]
        if len(user_ids) != len(set(user_ids)):
            raise ValueError("Duplicate user_id detected in split specifications.")

        # 2. Split type-specific validations
        if self.split_type == SplitType.EXACT:
            for s in self.splits:
                if s.amount is None:
                    raise ValueError("All split items must specify 'amount' when split_type is EXACT.")
            total_split_amount = sum(s.amount for s in self.splits)
            if total_split_amount != self.amount:
                raise ValueError(
                    f"Sum of EXACT split amounts ({total_split_amount}) does not equal total expense amount ({self.amount})."
                )

        elif self.split_type == SplitType.PERCENTAGE:
            for s in self.splits:
                if s.percentage is None:
                    raise ValueError("All split items must specify 'percentage' when split_type is PERCENTAGE.")
            total_percentage = sum(s.percentage for s in self.splits)
            if total_percentage != Decimal("100.00"):
                raise ValueError(
                    f"Sum of split percentages ({total_percentage}) must equal 100.00%."
                )

        elif self.split_type == SplitType.SHARES:
            for s in self.splits:
                if s.shares is None or s.shares <= Decimal("0"):
                    raise ValueError("All split items must specify a positive 'shares' value when split_type is SHARES.")
            total_shares = sum(s.shares for s in self.splits)
            if total_shares <= Decimal("0"):
                raise ValueError("Total shares must be greater than 0.")

        return self


class CalculatedSplit(BaseModel):
    user_id: UUID
    amount: Decimal = Field(..., decimal_places=2)
    percentage: Optional[Decimal] = None
    shares: Optional[Decimal] = None


class ExpenseSplitResponse(BaseModel):
    id: UUID
    expense_id: UUID
    user_id: UUID
    amount: Decimal
    percentage: Optional[Decimal] = None
    shares: Optional[Decimal] = None
    created_at: datetime


class ExpenseResponse(BaseModel):
    id: UUID
    group_id: UUID
    paid_by: UUID
    amount: Decimal
    currency: str
    description: str
    split_type: SplitType
    created_at: datetime
    splits: List[ExpenseSplitResponse]


class DebtSettlement(BaseModel):
    from_user_id: UUID = Field(..., description="Debtor who owes money")
    to_user_id: UUID = Field(..., description="Creditor who should receive money")
    amount: Decimal = Field(..., decimal_places=2, gt=0, description="Settlement amount to transfer")
    currency: str = Field(default="USD")
