class_name Money
## 金额显示：亿 / 万 / 元


static func short(v: float) -> String:
	var a := absf(v)
	var sign := "-" if v < 0 else ""
	if a >= 1e8:
		return "%s¥%.2f亿" % [sign, a / 1e8]
	if a >= 1e4:
		return "%s¥%.1f万" % [sign, a / 1e4]
	return "%s¥%.0f" % [sign, a]


static func full(v: float) -> String:
	return ("-¥" if v < 0 else "¥") + PyFmt.signed_thousands(absf(v)).substr(1)
