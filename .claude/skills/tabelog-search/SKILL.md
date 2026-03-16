---
name: tabelog-search
description: >
  Use this skill whenever the user wants to find, search, or discover restaurants in Japan using Tabelog (食べログ),
  Japan's largest restaurant review platform. Triggers include: asking for restaurant recommendations in a specific
  Japanese city, station, or neighborhood; searching for a specific cuisine type in Japan; wanting to see top-rated
  or highly ranked restaurants in a Japanese area; comparing restaurant reviews or scores on Tabelog; or any request
  like "find me good ramen near Osaka", "top sushi restaurants in Ginza", "食べログで調べて", "Tabelog rankings for X",
  or "幫我查大阪梅田附近的燒肉". Always use this skill when the user wants Japan restaurant data from Tabelog —
  do not attempt Tabelog searches without following this workflow.
compatibility: "Requires Claude in Chrome (MCP) for browser automation"
---

# Tabelog Restaurant Search

Automates a browser session on **tabelog.com** (Japanese language) to search for restaurants by location and cuisine,
then sorts by ranking to surface top-rated results.

---

## Prerequisites

You **must** have the **Claude in Chrome** MCP tools available:
- `tabs_context_mcp` / `tabs_create_mcp`
- `navigate`
- `find` / `form_input` / `computer`
- `javascript_tool` (for data extraction)

If these tools are unavailable, tell the user to enable Claude in Chrome and try again.

---

## Workflow

### Step 0 — Gather Parameters

Before starting the browser, confirm with the user:

| Parameter | Description | Example |
|-----------|-------------|---------|
| `location` | Station or area name **in Japanese** | `梅田`, `新大阪駅`, `難波` |
| `cuisine` (optional) | Food type **in Japanese** | `ラーメン`, `焼肉`, `寿司`, `イタリアン` |
| `sort_by` | Sort order: `ranking` (by score) or `review_count` (by number of reviews) | default: `ranking` |
| `open_top_result` | Whether to click into the #1 result for details | default: yes |

**Sort mode decision** — determine `sort_by` from the user's request:
- Use `ranking` (default) unless the user explicitly asks to sort by review count, e.g. "依評論數", "by most reviews", "口コミが多い順"
- When in doubt, use `ranking`

**Location translation reference** — convert user input before searching:

| User says | Search as |
|-----------|-----------|
| 大阪 / Osaka Umeda / 梅田 | `梅田` |
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

---

### Step 1 — Open Tabelog

```
tabs_context_mcp(createIfEmpty: true)
tabs_create_mcp()        ← always open a fresh tab
navigate(url: "https://tabelog.com")
```

Take a screenshot to confirm the homepage loaded correctly.

---

### Step 2 — Fill the Search Fields

Tabelog's homepage has two main search inputs:

| Field | Placeholder text | What to enter |
|-------|-----------------|---------------|
| Left input | `エリア・駅 [例:銀座、渋谷]` | `location` value |
| Center input | `キーワード [例:焼肉、店名、個室]` | `cuisine` value (skip if none) |

**Use `find` + `form_input` (confirmed working):**

```
find(query: "area station search input エリア・駅")
→ form_input(ref: <ref>, value: "<location>")

find(query: "keyword search input キーワード")
→ form_input(ref: <ref>, value: "<cuisine>")
```

**Fallback** if `form_input` leaves the field empty:
```
computer(action: "left_click", coordinate: <input coords>)
computer(action: "key", text: "ctrl+a")
computer(action: "type", text: "<value>")
```

---

### Step 3 — Submit Search

```
find(query: "検索 search button yellow")
→ computer(action: "left_click", ref: <ref>)
```

Take a screenshot to verify the results page loaded (title should read `[場所]の[料理]のお店`).

---

### Step 4 — Switch Sort Tab

Choose the tab based on `sort_by`:

| `sort_by` | Tab to click | Tab label |
|-----------|-------------|-----------|
| `ranking` (default) | `ランキング` | Sort by score/rating |
| `review_count` | `口コミが多い順` | Sort by number of reviews |

```
find(query: "<tab label> tab")
→ computer(action: "left_click", ref: <ref>)   ← click the link ref, not the generic text ref
```

Take a screenshot to confirm the correct tab is now active (highlighted/underlined).

---

### Step 5 — Extract Results

> ⚠️ `get_page_text` **does not work** on Tabelog result pages (page body is too large).
> Use the JavaScript method below instead.

**First, scroll down to trigger lazy-loading of all restaurant cards:**
```
computer(action: "scroll", coordinate: [756, 400], scroll_direction: "down", scroll_amount: 5)
computer(action: "wait", duration: 1)
```

**Then extract data with `javascript_tool`:**

```javascript
// Step A: find the correct container class
const sample = document.querySelector('[class*="list-rst"][class*="ranking"]');
console.log(sample?.className);

// Step B: extract top results
const items = document.querySelectorAll('li[class*="list-rst"]');
const results = [];
items.forEach((item, i) => {
  const name = item.querySelector('[class*="rst-name-main"]')?.textContent?.trim();
  const score = item.querySelector('[class*="c-rating__val"]')?.textContent?.trim();
  const reviewCount = item.querySelector('[class*="list-rst__comment-count"]')?.textContent?.trim();
  const location = item.querySelector('[class*="list-rst__area-genre"]')?.textContent?.trim();
  const budget = item.querySelector('[class*="c-table-budget__price"]')?.textContent?.trim();
  const tagline = item.querySelector('[class*="list-rst__strong-point"]')?.textContent?.trim();
  const url = item.querySelector('a[href*="tabelog.com"]')?.href;
  if (name) results.push({ rank: i + 1, name, score, reviewCount, location, budget, tagline, url });
});
JSON.stringify(results.slice(0, 10), null, 2);
```

**If JavaScript returns empty array**, fall back to screenshot-based reading:
```
computer(action: "screenshot")
```
Read the visible restaurant cards directly from the screenshot. Scroll down and take additional
screenshots to collect all top results.

---

### Step 6 — Open Top Result (if `open_top_result` is true)

```
find(query: "first ranked restaurant name link")
→ computer(action: "left_click", ref: <ref>)
```

On the detail page, collect:
- Full concept / description (お店の特徴)
- Business hours — `営業時間`
- Regular holiday — `定休日`
- Reservation availability — `予約可否`
- Address — `住所`
- Any notable dishes or course menus

**Detail page extraction** — use `javascript_tool`:
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
| Search returns 0 results | Widen location (area name instead of specific exit), remove cuisine filter, report to user |
| Sort tab not found | Scroll up; the 4 tabs are: `標準` / `ランキング` / `口コミが多い順` / `ニューオープン` |
| Page loads in English | Navigate to `https://tabelog.com` (no `/en/`) — Japanese is the default |
| `find` returns 2 refs for the tab | Use the `link` ref (not the `generic` text ref) |
| JavaScript returns `[]` | Tabelog may have updated CSS class names — use screenshot fallback |
| CAPTCHA / rate limit | Stop immediately, screenshot, and tell the user |
| Detail page fails to load | Report the restaurant name + URL to user, skip to next result |

---

## Output Format

Present results in **Traditional Chinese**, formatted as:

```
📍 梅田駅 附近燒肉餐廳排名（食べログ）

🥇 第1名：北新地やまがた屋
   評分：3.77 ｜ 評論數：176則
   類型：ホルモン、焼肉、鍋
   最近車站：梅田駅 791m（北新地駅 267m）
   晚餐預算：¥20,000〜¥29,999
   特色：北新地隱藏版燒肉名店，2025年百名店認定

🥈 第2名：焼肉フトロ
   評分：3.75 ｜ 評論數：180則
   ...

（最多列出前5~10名）

---
💡 資料來源：食べログ（tabelog.com）
⚠️  食べログ評分說明：3.5以上為良好，3.8以上為優秀
```

---

## Scoring Reference

| Score | Level |
|-------|-------|
| 4.0+ | 極少數頂級名店 |
| 3.8–3.99 | 優秀，強烈推薦 |
| 3.5–3.79 | 良好，值得一訪 |
| 3.0–3.49 | 普通水準 |
| 3.0以下 | 評價偏低 |

---

## Notes

- Always use **Japanese text** for both search fields — Tabelog search is optimized for Japanese.
- 「駅」(station) searches give more geographically precise results than broad area names.
- The `百名店` badge (百名店 2024/2025) on a result card indicates the restaurant is on Tabelog's
  annual "Top 100 Restaurants" list — a strong quality signal worth highlighting in your report.
- Tabelog結果頁 tabs from left to right: `標準【予約・PR店舗優先順】` → `ランキング` → `口コミが多い順` → `ニューオープン`
