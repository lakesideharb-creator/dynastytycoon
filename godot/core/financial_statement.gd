class_name FinancialStatement
extends RefCounted
## 月度财务结账单（对应 src/models.py FinancialStatement）

var month: int
var gross_revenue: float
var rent_expense: float
var payroll_expense: float
var marketing_expense: float
var miscellaneous_cost: float
var total_cost: float
var net_profit: float
var ending_cash: float
var f_time: float
var f_space: float
var f_person: float
var maintenance_expense: float = 0.0


static func from_dict(d: Dictionary) -> FinancialStatement:
	var s := FinancialStatement.new()
	s.month = int(d["month"])
	for k in ["gross_revenue", "rent_expense", "payroll_expense", "marketing_expense", "miscellaneous_cost",
			"total_cost", "net_profit", "ending_cash", "f_time", "f_space", "f_person", "maintenance_expense"]:
		s.set(k, float(d.get(k, 0.0)))
	return s


func to_dict() -> Dictionary:
	return {"month": month, "gross_revenue": gross_revenue, "rent_expense": rent_expense,
			"payroll_expense": payroll_expense, "marketing_expense": marketing_expense,
			"miscellaneous_cost": miscellaneous_cost, "total_cost": total_cost, "net_profit": net_profit,
			"ending_cash": ending_cash, "f_time": f_time, "f_space": f_space, "f_person": f_person,
			"maintenance_expense": maintenance_expense}
