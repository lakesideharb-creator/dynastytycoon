class_name PyFmt
## 与 Python 行为保持一致的数值工具。
## Godot 的 "%.Nf" 与 Python 的 f"{x:.Nf}" 舍入结果一致（已用边界值验证），
## 因此 round_to 先格式化再解析，等价于 Python 的 round(x, n)。


static func round_to(x: float, digits: int) -> float:
	return (("%." + str(digits) + "f") % x).to_float()


## Python f"{x:+,.0f}"：带符号、千分位、无小数
static func signed_thousands(x: float) -> String:
	var s := "%.0f" % absf(x)
	var out := ""
	var n := s.length()
	for i in n:
		out += s[i]
		var left := n - 1 - i
		if left > 0 and left % 3 == 0:
			out += ","
	var sign := "-" if x < 0 and s != "0" else "+"
	return sign + out
