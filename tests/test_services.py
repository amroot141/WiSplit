import unittest
from decimal import Decimal
from uuid import uuid4

from app.schemas import (
    CreateExpenseRequest,
    SplitItemInput,
    SplitType,
)
from app.services.settlement import minimize_cash_flow
from app.services.split_calculator import calculate_splits


class TestServices(unittest.TestCase):
    def test_split_calculator_equal_rounding(self):
        u1, u2, u3 = uuid4(), uuid4(), uuid4()
        req = CreateExpenseRequest(
            paid_by=u1,
            amount=Decimal("100.00"),
            currency="USD",
            description="Dinner",
            split_type=SplitType.EQUAL,
            splits=[
                SplitItemInput(user_id=u1),
                SplitItemInput(user_id=u2),
                SplitItemInput(user_id=u3),
            ],
        )
        splits = calculate_splits(req)
        total = sum(s.amount for s in splits)
        self.assertEqual(total, Decimal("100.00"))
        # Check that individual values are 33.34, 33.33, 33.33
        amounts = [s.amount for s in splits]
        self.assertIn(Decimal("33.34"), amounts)
        self.assertEqual(amounts.count(Decimal("33.33")), 2)

    def test_split_calculator_percentage(self):
        u1, u2, u3 = uuid4(), uuid4(), uuid4()
        req = CreateExpenseRequest(
            paid_by=u1,
            amount=Decimal("100.00"),
            currency="USD",
            description="Groceries",
            split_type=SplitType.PERCENTAGE,
            splits=[
                SplitItemInput(user_id=u1, percentage=Decimal("50.00")),
                SplitItemInput(user_id=u2, percentage=Decimal("25.00")),
                SplitItemInput(user_id=u3, percentage=Decimal("25.00")),
            ],
        )
        splits = calculate_splits(req)
        self.assertEqual(sum(s.amount for s in splits), Decimal("100.00"))
        self.assertEqual(splits[0].amount, Decimal("50.00"))
        self.assertEqual(splits[1].amount, Decimal("25.00"))
        self.assertEqual(splits[2].amount, Decimal("25.00"))

    def test_split_calculator_shares(self):
        u1, u2 = uuid4(), uuid4()
        req = CreateExpenseRequest(
            paid_by=u1,
            amount=Decimal("150.00"),
            currency="USD",
            description="Hotel",
            split_type=SplitType.SHARES,
            splits=[
                SplitItemInput(user_id=u1, shares=Decimal("1.0")),
                SplitItemInput(user_id=u2, shares=Decimal("2.0")),
            ],
        )
        splits = calculate_splits(req)
        self.assertEqual(sum(s.amount for s in splits), Decimal("150.00"))
        self.assertEqual(splits[0].amount, Decimal("50.00"))
        self.assertEqual(splits[1].amount, Decimal("100.00"))

    def test_minimize_cash_flow_simple(self):
        # A is owed 60, B owes 30, C owes 30
        uA, uB, uC = uuid4(), uuid4(), uuid4()
        balances = {
            uA: Decimal("60.00"),
            uB: Decimal("-30.00"),
            uC: Decimal("-30.00"),
        }
        settlements = minimize_cash_flow(balances)
        self.assertEqual(len(settlements), 2)
        total_settled = sum(s.amount for s in settlements)
        self.assertEqual(total_settled, Decimal("60.00"))
        for s in settlements:
            self.assertEqual(s.to_user_id, uA)
            self.assertIn(s.from_user_id, [uB, uC])
            self.assertEqual(s.amount, Decimal("30.00"))

    def test_minimize_cash_flow_multi_party(self):
        # A: +50, B: +30, C: -40, D: -40
        uA, uB, uC, uD = uuid4(), uuid4(), uuid4(), uuid4()
        balances = {
            uA: Decimal("50.00"),
            uB: Decimal("30.00"),
            uC: Decimal("-40.00"),
            uD: Decimal("-40.00"),
        }
        settlements = minimize_cash_flow(balances)
        # Sum of transactions must balance total debts (80.00)
        self.assertEqual(sum(s.amount for s in settlements), Decimal("80.00"))
        # Net balance verification:
        net_after = {uA: Decimal("0.00"), uB: Decimal("0.00"), uC: Decimal("0.00"), uD: Decimal("0.00")}
        for s in settlements:
            net_after[s.to_user_id] += s.amount
            net_after[s.from_user_id] -= s.amount
        self.assertEqual(net_after[uA], Decimal("50.00"))
        self.assertEqual(net_after[uB], Decimal("30.00"))
        self.assertEqual(net_after[uC], Decimal("-40.00"))
        self.assertEqual(net_after[uD], Decimal("-40.00"))


if __name__ == "__main__":
    unittest.main()
