---
name: tabelog-search
description: >
  Search for restaurants in Japan using Tabelog (食べログ), Japan's largest and most trusted
  restaurant review platform. Use this skill whenever the user asks about restaurants, food, or
  dining in any Japanese city, neighbourhood, or train station — even if they don't say "Tabelog"
  explicitly. Trigger phrases include: "find me good ramen near Osaka", "top sushi in Ginza",
  "best izakaya around Shibuya station", "食べログで調べて", "幫我查大阪梅田附近的燒肉",
  "where should I eat in Tokyo", or any request for restaurant recommendations in Japan.
  Don't try to search Tabelog manually — always follow this skill's workflow.
compatibility: "Requires any web browsing capability: Claude in Chrome (MCP), browser-use, agent-browser, or equivalent"
---

# Tabelog Restaurant Search

Automates a browser session on **tabelog.com** to find top-rated restaurants by location and cuisine,
sorted by score ranking (or by review count if the user asks).

---

## Prerequisites

This skill requires web browsing capability. Use whichever is available:

| Tool | Key capabilities needed |
|------|------------------------|
| **Claude in Chrome** (MCP) | `tabs_context_mcp`, `navigate`, `find`, `form_input`, `computer`, `javascript_tool` |
| **browser-use** | `browser_use` skill actions (navigate, click, type, extract) |
| **agent-browser** | equivalent navigate / interact / extract actions |

If no browsing tool is available, tell the user to enable one and try again.

Adapt the step-by-step instructions below to the available tool's action vocabulary —
the workflow logic (search → sort → extract → report) stays the same regardless of which tool you use.

---

## Step 0 — Clarify Parameters

Determine the following from the user's request. Ask only for what's missing.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `location` | Area or station name in Japanese (see translation table below) | required |
| `cuisine` | Food type in Japanese, e.g. `ラーメン`, `焼肉`, `寿司` | none (broader results) |
| `sort_by` | `ranking` = sort by score; `review_count` = sort by number of reviews | `ranking` |
| `open_top_result` | Open the #1 result for full details | yes |

**Choosing `sort_by`**: Use `ranking` by default — it surfaces the most acclaimed restaurants based
on Tabelog's composite score, which is a more reliable quality signal. Switch to `review_count`
only when the user explicitly asks, e.g. "依評論數", "by most reviews", "口コミが多い順".

**Location translation** — convert the user's input to Japanese before searching,
since Tabelog search is optimised for Japanese text:

| User says | Search as |
|-----------|-----------|
| 大阪 / Osaka / Umeda / 梅田 | `梅田` |
| 難波 / Namba / 道頓堀 | `なんば` |
| 心斎橋 / Shinsaibashi | `心斎橋` |
| 新大阪 / Shin-Osaka | `新大阪` |
| 天王寺 | `天王寺` |
| 新宿 / Shinjuku | `新宿` |
| 渋谷 / Shibuya | `渋谷` |
| 銀座 / Ginza | `銀座` |
| 札幌 / Sapporo | `札幌` |
| 名古屋 / Nagoya | `名古屋` |
| 福岡 / Fukuoka | `博多` or `天神` |

Station-level searches (e.g. `梅田駅`) give more geographically precise results than broad area names.

---

## Step 1 — Open Tabelog

```
tabs_context_mcp(createIfEmpty: true)
tabs_create_mcp()
navigate(url: "https://tabelog.com")
```

Take a screenshot to confirm the Japanese homepage loaded. If the page appears in English,
navigate again — the default URL serves Japanese without a language path segment.

---

## Step 2 — Fill Search Fields

The homepage has two inputs:

| Field | Placeholder | Value |
|-------|------------|-------|
| Left | `エリア・駅 [例:銀座、渋谷]` | `location` |
| Centre | `キーワード [例:焼肉、店名、個室]` | `cuisine` (skip if none) |

Fill using `find` + `form_input`:

```
find(query: "area station search input エリア・駅")
→ form_input(ref: <ref>, value: "<location>")

find(query: "keyword search input キーワード")
→ form_input(ref: <ref>, value: "<cuisine>")
```

If `form_input` leaves a field empty, click it and type directly:

```
computer(action: "left_click", coordinate: <input coords>)
computer(action: "key", text: "ctrl+a")
computer(action: "type", text: "<value>")
```

---

## Step 3 — Submit Search

```
find(query: "検索 search button yellow")
→ computer(action: "left_click", ref: <ref>)
```

Take a screenshot to verify the results page loaded (title format: `[場所]の[料理]のお店`).

---

## Step 4 — Switch Sort Tab

Click the appropriate tab based on `sort_by`:

| `sort_by` | Tab label |
|-----------|-----------|
| `ranking` (default) | `ランキング` |
| `review_count` | `口コミが多い順` |

```
find(query: "<tab label> tab")
→ computer(action: "left_click", ref: <link ref>)
```

If `find` returns two refs for the same label, use the `link` ref rather than the `generic` text ref.
Take a screenshot to confirm the tab is now active (highlighted/underlined).

The four tabs in order are: `標準` → `ランキング` → `口コミが多い順` → `ニューオープン`.
If the target tab isn't visible, scroll up.

---

## Step 5 — Extract Results

Tabelog result pages are too large for `get_page_text`. Use JavaScript instead.

First, scroll to trigger lazy-loading:

```
computer(action: "scroll", coordinate: [756, 400], scroll_direction: "down", scroll_amount: 5)
computer(action: "wait", duration: 1)
```

Then extract with `javascript_tool`:

```javascript
const items = document.querySelectorAll('li[class*="list-rst"]');
const results = [];
items.forEach((item, i) => {
  const name     = item.querySelector('[class*="rst-name-main"]')?.textContent?.trim();
  const score    = item.querySelector('[class*="c-rating__val"]')?.textContent?.trim();
  const reviews  = item.querySelector('[class*="list-rst__comment-count"]')?.textContent?.trim();
  const location = item.querySelector('[class*="list-rst__area-genre"]')?.textContent?.trim();
  const budget   = item.querySelector('[class*="c-table-budget__price"]')?.textContent?.trim();
  const tagline  = item.querySelector('[class*="list-rst__strong-point"]')?.textContent?.trim();
  const url      = item.querySelector('a[href*="tabelog.com"]')?.href;
  if (name) results.push({ rank: i + 1, name, score, reviews, location, budget, tagline, url });
});
JSON.stringify(results.slice(0, 10), null, 2);
```

If JavaScript returns an empty array (Tabelog may have updated its CSS class names), fall back to
screenshots: take a screenshot, read visible cards, scroll down and repeat as needed.

---

## Step 6 — Open Top Result (if `open_top_result` is true)

```
find(query: "first ranked restaurant name link")
→ computer(action: "left_click", ref: <ref>)
```

On the detail page, collect:
- Concept / description (お店の特徴)
- Business hours (営業時間) and regular holiday (定休日)
- Reservation availability (予約可否)
- Address (住所)
- Notable dishes or course menus

Extract with `javascript_tool`:

```javascript
const fields = {};
document.querySelectorAll('.rstinfo-table tr').forEach(row => {
  const label = row.querySelector('th')?.textContent?.trim();
  const value = row.querySelector('td')?.textContent?.trim();
  if (label && value) fields[label] = value;
});
JSON.stringify(fields, null, 2);
```

---

## Error Handling

| Situation | Resolution |
|-----------|------------|
| 0 results | Broaden the location (area instead of specific exit); remove cuisine filter; report to user |
| CAPTCHA / rate limit | Stop, screenshot, and tell the user |
| Detail page fails to load | Report restaurant name + URL to user, skip to next result |

---

## Output Format

Present results in Traditional Chinese:

```
📍 梅田駅 附近燒肉餐廳排名（食べログ）

🥇 第1名：北新地やまがた屋
   評分：3.77 ｜ 評論數：176則
   類型：ホルモン、焼肉、鍋
   最近車站：梅田駅 791m（北新地駅 267m）
   晚餐預算：¥20,000〜¥29,999
   特色：北新地隱藏版燒肉名店，2025年百名店認定 🏅

🥈 第2名：焼肉フトロ
   評分：3.75 ｜ 評論數：180則
   ...

（最多列出前5~10名）

💡 資料來源：食べログ（tabelog.com）
⚠️  評分說明：3.5以上良好，3.8以上優秀，4.0以上為頂級名店
```

Highlight the `百名店` badge (百名店 2024/2025) when present — it means the restaurant made
Tabelog's annual Top 100 list and is a strong quality signal worth calling out.

---

## Scoring Reference

| Score | Level |
|-------|-------|
| 4.0+ | 極少數頂級名店 |
| 3.8–3.99 | 優秀，強烈推薦 |
| 3.5–3.79 | 良好，值得一訪 |
| 3.0–3.49 | 普通水準 |
| 3.0以下 | 評價偏低 |
