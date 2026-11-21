#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
试玩记录汇总：读取试玩者发回的 dynasty_tycoon_playtest_*.jsonl（网页版/桌面版「导出试玩记录」，或终端版 --playtest），
按战役、危机公关、自由沙盒分别统计，输出 Markdown 报告。

用法：
  python3 tools/analyze_playtests.py 试玩记录目录或文件... [--out 报告.md]
  每个文件视为一位试玩者（文件名即代号）；同一位试玩者多次导出时重复的局会自动去重。

报告内容：
  - 战役：结局分布与通关率、中途退出的月份、开局决断与各议题的选择分布及对应通关率、
          走了「理论可通关路线」（不计随机事件）的比例、风水工位使用率
  - 危机公关：终局类型分布、各阶段选择分布、最常见路线
  - 自由沙盒：评级分布、经营时长、退出年份、行业与门店规模、高管门派
  - 自动提示：几乎没人选 / 高度集中的选项、退出率过高、通关率过高或过低
"""
import argparse
import json
import os
import statistics
import sys
from collections import Counter, defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from src import tables  # noqa: E402

MIN_SAMPLE = 5            # 选择分布的提示至少需要这么多样本
RARE_SHARE = 0.10         # 低于此比例视为「几乎没人选」
DOMINANT_SHARE = 0.80     # 高于此比例视为「高度集中」


# ─── 读取 ───────────────────────────────────────────────────────────────────
def collect_files(paths):
    files = []
    for p in paths:
        if os.path.isdir(p):
            files += sorted(os.path.join(p, f) for f in os.listdir(p) if f.endswith(".jsonl"))
        elif os.path.isfile(p):
            files.append(p)
    return files


def load_rows(files):
    """返回 [(试玩者, 行)]；同一试玩者的重复行（多次导出）只保留一次；坏行跳过并计数"""
    rows, bad = [], 0
    for path in files:
        tester = os.path.splitext(os.path.basename(path))[0]
        seen = set()
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    bad += 1
                    continue
                key = json.dumps(row, sort_keys=True, ensure_ascii=False)
                if key in seen:
                    continue
                seen.add(key)
                rows.append((tester, row))
    return rows, bad


def mode_of(row):
    return row.get("mode", "campaign")


# ─── 工具 ───────────────────────────────────────────────────────────────────
def pct(n, d):
    return f"{n / d:.0%}" if d else "—"


def money(v):
    if v is None:
        return "—"
    return f"{v / 1e8:.2f}亿" if abs(v) >= 1e8 else f"{v / 1e4:.0f}万"


def median(values):
    """中位数；整数结果不带小数点"""
    if not values:
        return None
    m = statistics.median(values)
    return int(m) if float(m).is_integer() else round(m, 1)


def table(header, rows):
    out = ["| " + " | ".join(header) + " |", "|" + "---|" * len(header)]
    out += ["| " + " | ".join(str(c) for c in r) + " |" for r in rows]
    return "\n".join(out)


def share_flags(label, counter, names, flags):
    """选择分布的自动提示"""
    total = sum(counter.values())
    if total < MIN_SAMPLE:
        return
    for key, name in names.items():
        share = counter.get(key, 0) / total
        tag = f"{key}「{name}」" if len(key) <= 2 else f"「{name}」"      # 危机选项的 id 很长，只显示名称
        if share < RARE_SHARE:
            flags.append(f"{label}：选项 {tag}只有 {pct(counter.get(key, 0), total)} 的人选（{total} 局）——文案是否让它显得明显很差，或它确实太弱？")
        elif share > DOMINANT_SHARE:
            flags.append(f"{label}：{pct(counter[key], total)} 的人选了 {tag}——选择可能过于明显。")


# ─── 战役 ───────────────────────────────────────────────────────────────────
_WINNING_PATHS = {}


def winning_paths(sid):
    """不计随机事件时可通关的全部路径（与 tools/campaign_paths.py 相同的穷举）"""
    if sid not in _WINNING_PATHS:
        from src.campaign_runner import enumerate_paths
        _WINNING_PATHS[sid] = {p for p, r in enumerate_paths(sid) if r.check_win()}
    return _WINNING_PATHS[sid]


def path_of(row, scen):
    order = [d["id"] for d in scen.get("decision_points", [])]
    dec = row.get("decisions") or {}
    return "|".join([row.get("main_choice", "")] + [f"{i}={dec[i]}" for i in order if i in dec])


def campaign_section(rows, flags, check_paths=True):
    scens = {s["id"]: s for s in tables.load("campaign_scenarios.json")["scenarios"]}
    by_sid = defaultdict(list)
    for tester, r in rows:
        by_sid[int(r.get("scenario", 0))].append((tester, r))
    out = ["## 战役"]
    if not by_sid:
        return out + ["（没有战役记录）"]
    for sid in sorted(by_sid):
        runs = by_sid[sid]
        scen = scens.get(sid, {"title": f"关卡{sid}", "choices": {}, "decision_points": []})
        outcomes = Counter(r["outcome"] for _, r in runs)
        finished = [r for _, r in runs if r["outcome"] != "quit"]
        wins = outcomes.get("win", 0)
        out.append(f"\n### {scen['title']}")
        out.append(f"共 {len(runs)} 局（{len({t for t, _ in runs})} 人）：通关 {wins}、未达标 {outcomes.get('lose', 0)}、"
                   f"破产 {outcomes.get('bankrupt', 0)}、中途退出 {outcomes.get('quit', 0)}。"
                   f"完成的局中通关率 **{pct(wins, len(finished))}**。")
        quits = [r.get("months_played", 0) for _, r in runs if r["outcome"] == "quit"]
        if quits:
            out.append(f"中途退出在第 {', '.join(str(m) for m in sorted(quits))} 个月（中位数 {median(quits)}）。")
        if len(runs) >= MIN_SAMPLE and outcomes.get("quit", 0) / len(runs) > 0.3:
            flags.append(f"{scen['title']}：{pct(outcomes['quit'], len(runs))} 的局中途退出——检查退出月份前后发生了什么。")
        if len(finished) >= MIN_SAMPLE:
            rate = wins / len(finished)
            if rate < 0.2 or rate > 0.8:
                flags.append(f"{scen['title']}：通关率 {rate:.0%}，{'偏难' if rate < 0.2 else '偏易'}。")

        mains = Counter(r.get("main_choice", "") for _, r in runs if r.get("main_choice"))
        names = {k: v.get("name", k) for k, v in scen.get("choices", {}).items()}
        rows_md = []
        for k in sorted(names):
            n = mains.get(k, 0)
            fin = [r for r in finished if r.get("main_choice") == k]
            w = sum(r["outcome"] == "win" for r in fin)
            rows_md.append([k, names[k], n, pct(n, sum(mains.values())), f"{w}/{len(fin)}"])
        out.append("\n**开局决断**\n")
        out.append(table(["选项", "内容", "次数", "占比", "通关/完成"], rows_md))
        share_flags(f"{scen['title']} 开局决断", mains, names, flags)

        for dp in scen.get("decision_points", []):
            picks = Counter(r["decisions"][dp["id"]] for _, r in runs if dp["id"] in (r.get("decisions") or {}))
            if not picks:
                continue
            opt_names = {o["key"]: o["label"] for o in dp["options"]}
            rows_md = []
            for k, label in opt_names.items():
                fin = [r for r in finished if (r.get("decisions") or {}).get(dp["id"]) == k]
                w = sum(r["outcome"] == "win" for r in fin)
                rows_md.append([k, label, picks.get(k, 0), pct(picks.get(k, 0), sum(picks.values())), f"{w}/{len(fin)}"])
            out.append(f"\n**第{dp['turn']}月议题：{dp['title']}**\n")
            out.append(table(["选项", "内容", "次数", "占比", "通关/完成"], rows_md))
            share_flags(f"{scen['title']}「{dp['title']}」", picks, opt_names, flags)

        complete = [r for r in finished if r.get("main_choice")]
        if check_paths and complete and scen.get("decision_points"):
            wp = winning_paths(sid)
            on_route = [r for r in complete if path_of(r, scen) in wp]
            lucky = [r for r in complete if path_of(r, scen) not in wp and r["outcome"] == "win"]
            unlucky = [r for r in on_route if r["outcome"] != "win"]
            out.append(f"\n走了理论可通关路线（不计随机事件）的：{len(on_route)}/{len(complete)}；"
                       f"其中没通关的 {len(unlucky)} 局（随机事件或营销/风水操作拖累）；"
                       f"不在可通关路线上却通关的 {len(lucky)} 局（随机事件、营销或风水改造帮了忙）。")
        scores = [r["office_score"] for _, r in runs if r.get("office_score") is not None]
        if scores:
            renovated = sum(s > 5 for s in scores)            # 开局恶煞布局评分为 5
            out.append(f"风水工位：{renovated}/{len(scores)} 局动过办公室布局（评分中位数 {median(scores)}）。")
        fr = [r["friction"] for _, r in runs if r.get("friction") is not None]
        if fr:
            out.append(f"期末组织内耗中位数 {median(fr):.0%}；期末现金中位数 {money(median([r['cash'] for _, r in runs]))}。")
    return out


# ─── 危机公关 ───────────────────────────────────────────────────────────────
def crisis_section(rows, flags):
    out = ["## 危机公关指挥室"]
    if not rows:
        return out + ["（没有危机公关记录）"]
    data = tables.load("crisis_scenarios.json")
    by_id = defaultdict(list)
    for t, r in rows:
        by_id[r.get("crisis", "")].append((t, r))
    for cid, runs in by_id.items():
        crisis = next((c for c in data["crises"] if c["id"] == cid), None)
        title = crisis["case_title"] if crisis else cid
        verdict_text = {k: v["text"].split("】")[0].lstrip("【") for k, v in crisis["verdicts"].items()} if crisis else {}
        outcomes = Counter(r["outcome"] for _, r in runs)
        verdicts = Counter(r.get("verdict") or "—" for _, r in runs)
        out.append(f"\n### {title}")
        out.append(f"共 {len(runs)} 局（{len({t for t, _ in runs})} 人）：卓越通关 {outcomes.get('win', 0)}、"
                   f"勉强过关 {outcomes.get('pass', 0)}、失败 {outcomes.get('fail', 0)}、中途退出 {outcomes.get('quit', 0)}。")
        out.append("\n" + table(["终局", "次数"], [[verdict_text.get(k, k), n] for k, n in verdicts.most_common()]))
        if crisis:
            for i, st in enumerate(crisis["stages"]):
                picks = Counter(r["decisions"][i] for _, r in runs if len(r.get("decisions", [])) > i)
                if not picks:
                    continue
                names = {o["id"]: o["title"].split("】")[0].lstrip("【") for o in st["options"]}
                out.append(f"\n**{st['hours_range']}**\n")
                out.append(table(["应对", "次数", "占比"], [[names[k], picks.get(k, 0), pct(picks.get(k, 0), sum(picks.values()))] for k in names]))
                share_flags(f"危机公关 {st['hours_range'].split(' (')[0]}", picks, names, flags)
        opt_title = {o["id"]: o["title"].split("】")[0].lstrip("【") for st in (crisis["stages"] if crisis else []) for o in st["options"]}
        paths = Counter(" → ".join(opt_title.get(d, d) for d in r.get("decisions", [])) for _, r in runs if r.get("decisions"))
        if paths:
            out.append("\n最常见路线：\n")
            out += [f"- {p}（{n} 局）" for p, n in paths.most_common(3)]
    return out


# ─── 自由沙盒 ───────────────────────────────────────────────────────────────
def sandbox_section(rows, flags):
    out = ["## 自由沙盒"]
    if not rows:
        return out + ["（没有自由沙盒记录）"]
    sb = tables.load("sandbox.json")
    ind_names = {i["key"]: i["name"] for i in sb["industries"]}
    gates = sb["gate_names"]
    runs = [r for _, r in rows]
    outcomes = Counter(r["outcome"] for r in runs)
    out.append(f"共 {len(runs)} 局（{len({t for t, _ in rows})} 人）：打满二十年 {sum(outcomes[g] for g in 'SABCD' if g != 'D')}、"
               f"破产 {outcomes.get('D', 0)}、提前封盘 {outcomes.get('sealed', 0)}、中途离开 {outcomes.get('quit', 0)}。")
    grades = Counter(r.get("grade") for r in runs if r["outcome"] not in ("quit",))
    out.append("\n" + table(["评级（含提前封盘时的评级）", "次数"], [[g, grades.get(g, 0)] for g in "SABCD"]))
    months = [r.get("months_played", 0) for r in runs]
    out.append(f"\n经营时长中位数 {median(months)} 个月（最短 {min(months)}，最长 {max(months)}）。")
    quits = Counter(r.get("year") for r in runs if r["outcome"] == "quit")
    if quits:
        out.append("中途离开的年份：" + "、".join(f"{y}年×{n}" for y, n in sorted(quits.items())) + "。")
    if len(runs) >= MIN_SAMPLE and outcomes.get("quit", 0) / len(runs) > 0.5:
        flags.append(f"自由沙盒：{pct(outcomes['quit'], len(runs))} 的局中途离开——二十年太长，或中后期缺少新目标？")
    inds = Counter(r.get("industry") for r in runs)
    out.append("\n" + table(["行业", "局数", "破产", "门店中位数", "净资产中位数"], [
        [ind_names.get(k, k), n, sum(1 for r in runs if r.get("industry") == k and r["outcome"] == "D"),
         median([r.get("stores", 0) for r in runs if r.get("industry") == k]),
         money(median([r.get("net_assets", 0) for r in runs if r.get("industry") == k]))]
        for k, n in inds.most_common()]))
    hires = Counter(e.split(":")[1] for r in runs for e in r.get("executives", []) if ":" in e)
    if hires:
        out.append("\n高管门派：" + "、".join(f"{gates.get(g, g)}×{n}" for g, n in hires.most_common()) + "。")
    no_exec = sum(1 for r in runs if not r.get("executives"))
    if no_exec:
        out.append(f"有 {no_exec} 局一个高管都没雇——人才市场入口是否不够显眼？")
        if len(runs) >= MIN_SAMPLE and no_exec / len(runs) > 0.3:
            flags.append(f"自由沙盒：{pct(no_exec, len(runs))} 的局没有雇佣任何高管。")
    scores = [r["office_score"] for r in runs if r.get("office_score") is not None]
    if scores:
        out.append(f"风水工位：{sum(s > 5 for s in scores)}/{len(scores)} 局动过办公室布局。")
    return out


# ─── 汇总 ───────────────────────────────────────────────────────────────────
def build_report(rows, bad=0, check_paths=True):
    by_mode = defaultdict(list)
    for t, r in rows:
        by_mode[mode_of(r)].append((t, r))
    testers = sorted({t for t, _ in rows})
    flags = []
    out = ["# 试玩记录汇总", ""]
    out.append(f"{len(testers)} 位试玩者，{len(rows)} 局：战役 {len(by_mode['campaign'])}、危机公关 {len(by_mode['crisis'])}、"
               f"自由沙盒 {len(by_mode['sandbox'])}。" + (f"（跳过 {bad} 行无法解析的记录）" if bad else ""))
    plats = Counter(r.get("platform", "终端版") for _, r in rows)
    out.append("平台：" + "、".join(f"{p}×{n}" for p, n in plats.most_common()) + "。")
    out.append("\n" + table(["试玩者", "局数", "战役（通关/局）", "危机公关", "自由沙盒（评级）"], [
        [t, sum(1 for x, _ in rows if x == t),
         f"{sum(1 for x, r in by_mode['campaign'] if x == t and r['outcome'] == 'win')}/{sum(1 for x, _ in by_mode['campaign'] if x == t)}",
         "、".join(r["outcome"] for x, r in by_mode["crisis"] if x == t) or "—",
         "、".join(str(r.get("grade")) + ("（离开）" if r["outcome"] == "quit" else "") for x, r in by_mode["sandbox"] if x == t) or "—"]
        for t in testers]))
    body = []
    body += [""] + campaign_section(by_mode["campaign"], flags, check_paths)
    body += [""] + crisis_section(by_mode["crisis"], flags)
    body += [""] + sandbox_section(by_mode["sandbox"], flags)
    out += ["", "## 需要关注", ""]
    out += [f"- {f}" for f in flags] if flags else ["- 暂无自动提示（样本少于 %d 局的选择分布不做判断）。" % MIN_SAMPLE]
    out += body
    out += ["", "---", "", "自动统计只能说明玩家「做了什么」；「为什么」要结合观察记录表与访谈（见 docs/08_Playtest_Guide.md）。"]
    return "\n".join(out) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="+", help="试玩记录文件或目录（*.jsonl）")
    ap.add_argument("--out", help="把报告写入文件（默认打印）")
    ap.add_argument("--no-paths", action="store_true", help="不做可通关路线对照（穷举较慢时可关闭）")
    args = ap.parse_args(argv)
    files = collect_files(args.paths)
    if not files:
        sys.exit("没有找到 .jsonl 试玩记录文件")
    rows, bad = load_rows(files)
    report = build_report(rows, bad, check_paths=not args.no_paths)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(report)
        print(f"已写入 {args.out}（{len(rows)} 局）")
    else:
        print(report)


if __name__ == "__main__":
    main()
