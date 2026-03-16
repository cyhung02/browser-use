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
| **browser-use** | `open`, `click`, `type`, `eval`, `state`, `screenshot` |
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
| `open_top_n` | How many results to open for full details (intro + hours + budget) | 1 |

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
| 新宿 / Shinjuku | `新宿駅` |
| 渋谷 / Shibuya | `渋谷` |
| 銀座 / Ginza | `銀座` |
| 札幌 / Sapporo | `札幌` |
| 名古屋 / Nagoya | `名古屋` |
| 福岡 / Fukuoka | `博多` or `天神` |
| 目黒 / Meguro | `目黒駅` |
| 上野 / Ueno | `上野駅` |

Adding 「駅」 to station names gives geographically precise results. Prefer `目黒駅` over `目黒`.

---

## Step 1 — Open Tabelog

Navigate to `https://tabelog.com`.

**⚠️ Language selector popup**: On a fresh session, Tabelog shows a language selection popup at the
bottom of the page. Click 「日本語」 to dismiss it before proceeding. If skipped, interactions may fail.

Confirm the Japanese homepage has loaded before moving on.

---

## Step 2 — Fill the Area Field (UI interaction required)

**Do NOT fill the area field by setting its value via JavaScript**, and **do NOT submit the form
via JavaScript** — both bypass Tabelog's area validation. The area will show 「全国」 (nationwide)
instead of the target station, and JS form submission triggers a Yahoo CAPTCHA.

The correct sequence is:

1. **Click** the area input (`name="sa"`, placeholder `エリア・駅 [例:銀座、渋谷]`)
2. **Type** the location name (e.g. `上野駅`) — this triggers an autocomplete dropdown
3. **Wait** ~1–2 seconds for the autocomplete suggestion to appear
4. **Click the autocomplete suggestion** matching the station name — this registers the area properly.
   The suggestion element type varies: it may be `<button>`, `<li>`, or `<div>`. Match by **text content**, not by element type.
5. Fill the keyword field (`name="sk"`) with the cuisine type if provided (skip if none)
6. **Click the 検索 button** — use ID `js-global-search-btn` for reliable targeting

Without step 4, the search defaults to nationwide results even if the input shows the station name.

---

## Step 3 — Verify Search Results Page

The page title after a successful search starts with the station name:

| Condition | Title pattern |
|-----------|--------------|
| With cuisine | `[駅名]でおすすめの美味しい[料理]をご紹介！ \| 食べログ` |
| Without cuisine | `[駅名]でおすすめのグルメ情報をご紹介！ \| 食べログ` |

If the title shows 「全国のお店」 or does not start with the station name, the area filter didn't apply — repeat Step 2.

---

## Step 4 — Switch Sort Tab

| `sort_by` | Tab label |
|-----------|-----------|
| `ranking` (default) | `ランキング` |
| `review_count` | `口コミが多い順` |

**Recommended — navigate directly by URL** (more reliable than clicking):

```javascript
// Get the target tab URL from the page and navigate to it
Array.from(document.querySelectorAll('a'))
  .filter(function(a) { return a.textContent.trim() === 'ランキング'; })
  .map(function(a) { return a.href; })
  .join('|')
```

Take the returned URL and navigate to it directly with `browser-use open <url>`.

**Fallback — click the tab** if JS returns empty:
Find the tab link by text `ランキング` in the page state and click it.
The four tabs in order: `標準` → `ランキング` → `口コミが多い順` → `ニューオープン`.

Confirm success: page title should include 「ランキング」.

---

## Step 5 — Extract Results

Scroll down ~1000px to ensure all cards are rendered, then extract with JavaScript.

### Confirmed CSS class names (as of 2025–2026)

| Data | Selector |
|------|----------|
| Restaurant cards | `.list-rst--ranking` |
| Name + rank number | `a[data-ranking]` — `data-ranking` attribute = rank, text = name |
| Score | `.c-rating__val--strong` |
| Review count | `.list-rst__rvw-count-num` |
| Area / distance | `.list-rst__area-genre` |
| 百名店 badge | `[class*="hyakumeiten"]` |

### Extraction script

**Important for browser-use**: `console.log()` output is not captured — only the final expression
value is returned. Avoid complex multi-statement scripts; use simple single-expression evals or
pipe-delimited string building to stay reliable.

```javascript
// Run this as a single eval — returns pipe-delimited rows, one restaurant per line
(function() {
  var links = document.querySelectorAll('a[data-ranking]');
  var out = [];
  for (var i = 0; i < Math.min(10, links.length); i++) {
    var l = links[i];
    var card = l.closest('.list-rst--ranking');
    var score   = card.querySelector('.c-rating__val--strong')?.textContent?.trim() || '';
    var reviews = card.querySelector('.list-rst__rvw-count-num')?.textContent?.trim() || '';
    var area    = (card.querySelector('.list-rst__area-genre')?.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 60);
    var badge   = card.querySelector('[class*="hyakumeiten"]') ? '百名店' : '';
    out.push(l.dataset.ranking + '|' + l.textContent.trim() + '|' + score + '|' + reviews + '|' + area + '|' + badge + '|' + l.href);
  }
  return out.join('\n');
})()
```

Parse each line by splitting on `|`:
`rank | name | score | reviewCount | areaGenre | badge | url`

If the script returns empty, fall back to screenshots and read the cards visually.

---

## Step 6 — Open Detail Pages (for top `open_top_n` results)

### When `open_top_n` > 1 — use parallel subagents (recommended)

Spawn one subagent per restaurant in the **same message** so they run concurrently.
Each subagent gets an isolated browser session via `--session r1`, `--session r2`, etc.

Subagent prompt template (repeat for each restaurant, changing session name and URL):

```
Use browser-use CLI to extract restaurant details from Tabelog.
Run in sequence:
1. browser-use --session r<N> open "<url>"
2. (wait 2 seconds)
3. browser-use --session r<N> eval "document.querySelector('.p-rst-intro__txt, .pr-comment, .rstdtl-top__pr-comment-body')?.textContent?.trim()?.slice(0, 200)"
4. browser-use --session r<N> eval "(function(){ var f={}; document.querySelectorAll('.rstinfo-table tr').forEach(function(r){ var l=r.querySelector('th')?.textContent?.trim(); var v=r.querySelector('td')?.textContent?.replace(/\s+/g,' ').trim().slice(0,100); if(l&&v) f[l]=v; }); return JSON.stringify(f); })()"
5. browser-use --session r<N> close
Return all output from steps 3 and 4.
```

> Note: The `want` array filter with Japanese strings can be unreliable in subagents.
> Extract the full info table (step 4 above) and let the subagent return everything —
> then filter to the fields you need when composing the final output.

### When `open_top_n` = 1 — navigate directly in main session

```javascript
// PR intro
document.querySelector('.p-rst-intro__txt, .pr-comment, .rstdtl-top__pr-comment-body')?.textContent?.trim()?.slice(0, 200)
```

```javascript
// Info table — full extraction, filter afterwards
(function() {
  var f = {};
  document.querySelectorAll('.rstinfo-table tr').forEach(function(row) {
    var label = row.querySelector('th')?.textContent?.trim();
    var value = row.querySelector('td')?.textContent?.replace(/\s+/g, ' ').trim().slice(0, 100);
    if (label && value) f[label] = value;
  });
  return JSON.stringify(f);
})()
```

Some restaurants (especially small casual shops) have no PR text — skip gracefully and use the info table only.

---

## Error Handling

| Situation | Resolution |
|-----------|------------|
| Language popup blocks interaction | Click 日本語 first |
| Area shows 全国 after search | Didn't click autocomplete suggestion — repeat Step 2 |
| Yahoo CAPTCHA appears | JS form submission was used — close, reopen Tabelog, use UI interactions only |
| 0 results | Widen location (area name instead of specific exit); remove cuisine filter |
| Sort tab click fails | Use JS to get tab URL, navigate directly (see Step 4) |
| JavaScript eval returns `None` | browser-use limitation — simplify to single expression; avoid console.log |
| JavaScript returns empty array | CSS classes may have changed — use screenshot fallback |
| CAPTCHA / rate limit | Stop, screenshot, and tell the user |
| Detail page: intro returns None | Restaurant has no PR text — skip gracefully, use info table only |
| Detail page fails to load | Report restaurant name + URL to user, skip to next result |

---

## Output Format

Present results in Traditional Chinese:

```
📍 目黒駅 附近拉麵排名（食べログ ランキング）

🥇 第1名：えーちゃん食堂
   評分：3.80 ｜ 評論數：1,052則
   距離：目黒駅 680m（不動前駅 659m）
   類型：ラーメン・つけ麺
   🏅 ラーメン TOKYO 百名店 2025

🥈 第2名：支那ソバ かづ屋
   評分：3.77 ｜ 評論數：1,763則
   ...

（最多列出前5~10名）

💡 資料來源：食べログ（tabelog.com）
⚠️  評分說明：3.5以上良好，3.8以上優秀，4.0以上為頂級名店
```

Highlight the 百名店 badge when present — it means the restaurant is on Tabelog's annual
Top 100 list and is a strong quality signal worth calling out.

---

## Scoring Reference

| Score | Level |
|-------|-------|
| 4.0+ | 極少數頂級名店 |
| 3.8–3.99 | 優秀，強烈推薦 |
| 3.5–3.79 | 良好，值得一訪 |
| 3.0–3.49 | 普通水準 |
| 3.0以下 | 評價偏低 |
