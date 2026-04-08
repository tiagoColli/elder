---
slug: standards/asana-output-rules
name: Asana Output Rules
description: Iron-clad formatting rules for producing valid Asana task HTML. Referenced by any skill whose output will be pasted into Asana.
---

# Asana Output Rules

These rules are **non-negotiable**. Any skill that produces content for Asana MUST follow every rule below without exception.

## 1. Always Use HTML — Never Plain Text

Your output for task descriptions MUST be valid Asana HTML.
Always wrap the entire content in `<body>...</body>`.

## 2. Allowed Tags Only

| Tag | Use |
|-----|-----|
| `<body>` | Required root wrapper |
| `<h1>`, `<h2>` | Section headers |
| `<strong>` | Bold emphasis |
| `<em>` | Italic emphasis |
| `<ul>`, `<ol>`, `<li>` | Lists |
| `<a href="URL">` | External links |
| `<code>` | Inline technical terms |
| `<blockquote>` | Quoted references |
| `<hr>` | Horizontal separator |
| `<table>`, `<tr>`, `<td>` | Tables |

**Forbidden tags (cause parsing errors):** `<p>`, `<br>`, `<div>`, `<span>`

Only `<a>` and `<img>` accept attributes. Any attribute on any other tag will be rejected by Asana.

## 3. Line Breaks

Use `\n` for line breaks — NEVER `<p>` or `<br>`.
Do NOT add `\n` immediately after `<body>` — start directly with `<h1>` or text.

## 4. Links

Always use descriptive link text — never paste raw URLs as text.

```
Correct:   <a href="https://drive.google.com/file/abc">Brief (Google Drive)</a>
Incorrect: https://drive.google.com/file/abc
```

## 5. Omit Empty Sections

Do NOT include section headers or placeholders for information the user did not provide.
If you have no content for a section, skip it entirely.

## 6. Output Only the HTML

Return only the `<body>...</body>` block. No explanation, no markdown, no commentary around it.

## 7. Validate Before Outputting

Before producing output, mentally verify:
- All tags are opened and closed in the correct order
- No forbidden tags are present
- No attributes appear on tags other than `<a>` and `<img>`
- Content starts immediately after `<body>` (no leading `\n`)
