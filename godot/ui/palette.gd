class_name Palette
## 美术规范色板（docs/09_Art_Audio_Prompts.md 第 0 节）

const PAPER := Color("#F3EEE3")        ## 宣纸米白
const INK := Color("#1C1C1C")          ## 墨黑
const TERMINAL := Color("#0E1116")     ## 终端深蓝黑
const TERMINAL_PANEL := Color("#151A21")
const TERMINAL_LINE := Color("#2A313B")
const CINNABAR := Color("#C8372D")     ## 朱砂红：亏损、危机
const GOLD := Color("#B8955A")         ## 鎏金：吉位、强调
const INDIGO := Color("#3D5A6C")       ## 青黛：中性信息
const AMBER := Color("#E8A33D")        ## 琥珀：终端数据高亮
const JADE := Color("#5FB08A")         ## 盈利
const TEXT := Color("#E6E1D6")         ## 终端主文字
const TEXT_DIM := Color("#8C939E")     ## 终端次要文字

## 五行主色
const ELEMENT := {
	"Wood": Color("#4E7D5B"), "Fire": Color("#C8372D"), "Earth": Color("#A0743F"),
	"Metal": Color("#D9D4C7"), "Water": Color("#2B3A4A"),
}


static func hex(c: Color) -> String:
	return "#" + c.to_html(false)
