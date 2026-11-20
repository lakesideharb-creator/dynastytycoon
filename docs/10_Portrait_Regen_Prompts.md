# 10 · 主角团立绘重绘提示词（品红底 · 12 张）

对应 `docs/09_Art_Audio_Prompts.md` 中的 batch1 返修：苏清墨、沈务本、赵勇 × 4 表情，全部在品红平涂底上重新生成，再抠成透明底。

## 生成流程

1. **每个角色先生成 neutral**，满意以后把它作为角色参考图，生成另外 3 个表情。Midjourney 用 `--cref <neutral图链接> --cw 100`，即梦 / SD 用参考图或 IP-Adapter。这样脸、服装和构图才统一。
2. 画幅 1:1（Midjourney 加 `--ar 1:1`），导出 1024×1024。
3. 每张都带上下面的**负面提示词**。
4. 文件名用 `{角色id}_{表情}.png`，生成完一起抠图：

```bash
python3 tools/remove_background.py --mode chroma 生成图/*.png --out godot/assets/portraits
```

### 负面提示词（12 张通用）

```
text, letters, watermark, signature, logo, ink splatter in background, paper texture, background texture, gradient background, vignette, drop shadow, cast shadow on background, pink clothing, magenta on character, purple accents, extra fingers, deformed hands, cropped head, anime chibi, photorealistic skin pores, low resolution
```

### 验收要点

- 背景是纯品红平涂，没有泼墨、纸纹、渐变或阴影。
- 4 个表情的构图一致：胸口以上，头在画面上三分之一。
- 人物身上没有粉色、紫色等接近品红的颜色（会被一起抠掉）。
- pleased / stressed / angry 和 neutral 一眼能看出区别。
- 赵勇指向前方的手指完整留在画面内。

---

## 苏清墨 `su_qingmo`（景门 · 火）

### su_qingmo_neutral.png

```
half-body character portrait of a Chinese business executive, facing three-quarter view, framed from mid-chest up with the head in the upper third, isolated on a solid flat pure magenta (#FF00FF) background, no ink splashes or shadows on the background, woman in her early 30s, elegant and visionary brand director, sleek low bun with a slim pale green jade hairpin, tailored ivory blazer with subtle pure cinnabar-red cloud embroidery on the lapel, small cinnabar-red square seal brooch, calm confident expression, mouth closed, relaxed brows, modern Chinese minimalist style, ink wash shading on the figure only, clean flat vector shapes, restrained palette of ivory, ink black, cinnabar red and muted gold, soft studio lighting, high detail, cohesive game art
```

### su_qingmo_pleased.png

```
half-body character portrait of a Chinese business executive, facing three-quarter view, framed from mid-chest up with the head in the upper third, isolated on a solid flat pure magenta (#FF00FF) background, no ink splashes or shadows on the background, woman in her early 30s, elegant and visionary brand director, sleek low bun with a slim pale green jade hairpin, tailored ivory blazer with subtle pure cinnabar-red cloud embroidery on the lapel, small cinnabar-red square seal brooch, warm open smile showing a hint of teeth, eyes slightly crinkled, raised cheeks, delighted and proud, modern Chinese minimalist style, ink wash shading on the figure only, clean flat vector shapes, restrained palette of ivory, ink black, cinnabar red and muted gold, soft studio lighting, high detail, cohesive game art
```

### su_qingmo_stressed.png

```
half-body character portrait of a Chinese business executive, facing three-quarter view, framed from mid-chest up with the head in the upper third, isolated on a solid flat pure magenta (#FF00FF) background, no ink splashes or shadows on the background, woman in her early 30s, elegant and visionary brand director, sleek low bun slightly loosened with a few strands falling, slim pale green jade hairpin, tailored ivory blazer with subtle pure cinnabar-red cloud embroidery on the lapel, small cinnabar-red square seal brooch, collar slightly open, exhausted expression, faint dark circles under eyes, worried brows, lips pressed, slightly slumped shoulders, modern Chinese minimalist style, ink wash shading on the figure only, clean flat vector shapes, restrained palette of ivory, ink black, cinnabar red and muted gold, soft studio lighting, high detail, cohesive game art
```

### su_qingmo_angry.png

```
half-body character portrait of a Chinese business executive, facing three-quarter view, framed from mid-chest up with the head in the upper third, isolated on a solid flat pure magenta (#FF00FF) background, no ink splashes or shadows on the background, woman in her early 30s, elegant and visionary brand director, sleek low bun with a slim pale green jade hairpin, tailored ivory blazer with subtle pure cinnabar-red cloud embroidery on the lapel, small cinnabar-red square seal brooch, arms crossed, tense jaw, furrowed brows, cold sharp glare, displeased, modern Chinese minimalist style, ink wash shading on the figure only, clean flat vector shapes, restrained palette of ivory, ink black, cinnabar red and muted gold, soft studio lighting, high detail, cohesive game art
```

---

## 沈务本 `shen_wuben`（生门 · 土）

### shen_wuben_neutral.png

```
half-body character portrait of a Chinese business executive, facing three-quarter view, framed from mid-chest up with the head in the upper third, isolated on a solid flat pure magenta (#FF00FF) background, no ink splashes or shadows on the background, man in his mid 40s, meticulous chief financial officer, round thin gold wire-rimmed glasses, neat side-parted black hair with grey at the temples, ochre-brown mandarin-collar jacket with knotted buttons, a tiny gold abacus clip at the collar, holding a brown leather ledger against his chest with one hand, calm confident expression, faint polite smile, mouth closed, modern Chinese minimalist style, ink wash shading on the figure only, clean flat vector shapes, restrained palette of ochre, ink black, cinnabar red and muted gold, soft warm studio lighting, high detail, cohesive game art
```

### shen_wuben_pleased.png

```
half-body character portrait of a Chinese business executive, facing three-quarter view, framed from mid-chest up with the head in the upper third, isolated on a solid flat pure magenta (#FF00FF) background, no ink splashes or shadows on the background, man in his mid 40s, meticulous chief financial officer, round thin gold wire-rimmed glasses, neat side-parted black hair with grey at the temples, ochre-brown mandarin-collar jacket with knotted buttons, a tiny gold abacus clip at the collar, holding a brown leather ledger against his chest with one hand, broad satisfied smile showing teeth, eyes crinkled behind the glasses, relaxed and pleased like the books finally balance, modern Chinese minimalist style, ink wash shading on the figure only, clean flat vector shapes, restrained palette of ochre, ink black, cinnabar red and muted gold, soft warm studio lighting, high detail, cohesive game art
```

### shen_wuben_stressed.png

```
half-body character portrait of a Chinese business executive, facing three-quarter view, framed from mid-chest up with the head in the upper third, isolated on a solid flat pure magenta (#FF00FF) background, no ink splashes or shadows on the background, man in his mid 40s, meticulous chief financial officer, round thin gold wire-rimmed glasses sitting slightly crooked, neat side-parted black hair with grey at the temples slightly messy, ochre-brown mandarin-collar jacket with the top button undone, a tiny gold abacus clip at the collar, holding a brown leather ledger against his chest with one hand, exhausted expression, dark circles under eyes, worried frown, slumped shoulders, modern Chinese minimalist style, ink wash shading on the figure only, clean flat vector shapes, restrained palette of ochre, ink black, cinnabar red and muted gold, soft warm studio lighting, high detail, cohesive game art
```

### shen_wuben_angry.png

```
half-body character portrait of a Chinese business executive, facing three-quarter view, framed from mid-chest up with the head in the upper third, isolated on a solid flat pure magenta (#FF00FF) background, no ink splashes or shadows on the background, man in his mid 40s, meticulous chief financial officer, round thin gold wire-rimmed glasses, neat side-parted black hair with grey at the temples, ochre-brown mandarin-collar jacket with knotted buttons, a tiny gold abacus clip at the collar, arms crossed over a brown leather ledger, tense jaw, furrowed brows, stern disapproving glare over the glasses, modern Chinese minimalist style, ink wash shading on the figure only, clean flat vector shapes, restrained palette of ochre, ink black, cinnabar red and muted gold, soft warm studio lighting, high detail, cohesive game art
```

---

## 赵勇 `zhao_yong`（伤门 · 木）

### zhao_yong_neutral.png

```
half-body character portrait of a Chinese business executive, facing three-quarter view, framed from mid-chest up with the head in the upper third, isolated on a solid flat pure magenta (#FF00FF) background, no ink splashes or shadows on the background, man in his late 30s, aggressive sales vice president, short buzz-cut black hair, dark bamboo-green shirt with sleeves rolled up, open collar, charcoal grey vest, thin cinnabar-red lanyard, gold wristwatch with dark green strap, leaning slightly forward and pointing ahead with the full hand and finger inside the frame, confident half smile, determined eyes, modern Chinese minimalist style, ink wash shading on the figure only, clean flat vector shapes, restrained palette of bamboo green, charcoal, ink black, cinnabar red and muted gold, dynamic studio lighting, high detail, cohesive game art
```

### zhao_yong_pleased.png

```
half-body character portrait of a Chinese business executive, facing three-quarter view, framed from mid-chest up with the head in the upper third, isolated on a solid flat pure magenta (#FF00FF) background, no ink splashes or shadows on the background, man in his late 30s, aggressive sales vice president, short buzz-cut black hair, dark bamboo-green shirt with sleeves rolled up, open collar, charcoal grey vest, thin cinnabar-red lanyard, gold wristwatch with dark green strap, fist pumped at chest height in triumph, wide grin showing teeth, eyes crinkled, energetic and victorious like he just closed a big deal, modern Chinese minimalist style, ink wash shading on the figure only, clean flat vector shapes, restrained palette of bamboo green, charcoal, ink black, cinnabar red and muted gold, dynamic studio lighting, high detail, cohesive game art
```

### zhao_yong_stressed.png

```
half-body character portrait of a Chinese business executive, facing three-quarter view, framed from mid-chest up with the head in the upper third, isolated on a solid flat pure magenta (#FF00FF) background, no ink splashes or shadows on the background, man in his late 30s, aggressive sales vice president, short buzz-cut black hair, dark bamboo-green shirt with sleeves rolled up and collar loosened, charcoal grey vest unbuttoned, thin cinnabar-red lanyard, gold wristwatch with dark green strap, rubbing the back of his neck with one hand, exhausted and drained, dark circles under eyes, heavy eyelids, slumped shoulders, tired sigh, modern Chinese minimalist style, ink wash shading on the figure only, clean flat vector shapes, restrained palette of bamboo green, charcoal, ink black, cinnabar red and muted gold, dim studio lighting, high detail, cohesive game art
```

### zhao_yong_angry.png

```
half-body character portrait of a Chinese business executive, facing three-quarter view, framed from mid-chest up with the head in the upper third, isolated on a solid flat pure magenta (#FF00FF) background, no ink splashes or shadows on the background, man in his late 30s, aggressive sales vice president, short buzz-cut black hair, dark bamboo-green shirt with sleeves rolled up, open collar, charcoal grey vest, thin cinnabar-red lanyard, gold wristwatch with dark green strap, arms crossed, tense jaw, furrowed brows, fierce glare, confrontational, modern Chinese minimalist style, ink wash shading on the figure only, clean flat vector shapes, restrained palette of bamboo green, charcoal, ink black, cinnabar red and muted gold, dynamic studio lighting, high detail, cohesive game art
```

---

## 和上一批相比改了什么

- **背景**：纯品红平涂，背景上没有泼墨、阴影或纸纹，水墨效果只画在人物身上。
- **构图**：12 张都固定为胸口以上、头在上三分之一，避免某一张镜头突然拉近。
- **表情差异拉开**：
  - pleased：露齿笑、眼角有笑纹；赵勇加了握拳庆祝的动作。
  - stressed：黑眼圈、塌肩、衣领松开；赵勇改为揉后颈的疲惫动作。
  - angry：统一为双臂交叉。
- **避免被抠掉的颜色**：写明"纯朱砂红"，负面提示词排除粉色和紫色。
