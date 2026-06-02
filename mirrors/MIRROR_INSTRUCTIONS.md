# Mirror deployment instructions

Two deployment options per site. Pick **one** per domain.

---

## Option A — Simple passthrough redirect

Best when you want traffic to flow straight through to the GitHub Pages canonical
URL. The redirect file carries the correct OG/Twitter Card metadata so link
previews still render the card before the browser follows the redirect.

| Domain | File to deploy | Suggested path on server |
|--------|---------------|--------------------------|
| texascrossroads.net | `texascrossroads_redirect.html` | Upload as `/parker/index.html` (so the URL is `texascrossroads.net/parker`) |
| henrylee.vote | `henrylee_redirect.html` | Upload as `/parker/index.html` (so the URL is `henrylee.vote/parker`) |

How it works:
- Both `<meta http-equiv="refresh">` and a JS `window.location.replace()` fire
  immediately — the visitor never sees the redirect page.
- OG metadata points to the correct domain so social crawlers (Facebook,
  Twitter/X, Bluesky, iMessage, Slack) pick up the image and description *from
  the mirror URL* before the redirect fires. The share preview will show
  `texascrossroads.net/parker` or `henrylee.vote/parker` as the source URL.

---

## Option B — Self-contained landing page (mirror)

Best when you want content to actually live on the domain and not bounce away.
The page replicates the index cards and key facts, and all interactive content
buttons (map, slides, GitHub) point to the canonical github.io URLs.

| Domain | File to deploy | Suggested path on server |
|--------|---------------|--------------------------|
| texascrossroads.net | `texascrossroads_index.html` | Upload as `/parker/index.html` |
| henrylee.vote | `henrylee_index.html` | Upload as `/parker/index.html` |

What the page includes:
- Branded breadcrumb bar ("Texas Crossroads · Parker Data Pro Populo")
- Four resource cards linking to the canonical GitHub Pages URLs
- "What's in scope" fact list (all five headline findings)
- "About this mirror" section with canonical URL attribution
- Full OG + Twitter Card metadata pointing to the mirror URL (og_card.png is
  fetched from the canonical GitHub Pages URL)

---

## WordPress / cPanel quick-deploy

If either site runs WordPress or a shared host with cPanel:

**Option A (redirect):**
1. SSH/SFTP into the host.
2. Create directory `public_html/parker/` if it doesn't exist.
3. Upload the redirect file as `public_html/parker/index.html`.
4. No plugin or .htaccess changes needed.

**Option B (landing page):**
Same steps — upload the full landing-page file as `public_html/parker/index.html`.
No PHP, no database, no dependencies. It's a static HTML file.

---

## Social links to use after deploying

Use whichever domain you post from:

```
https://texascrossroads.net/parker
https://henrylee.vote/parker
```

Both will produce the correct rich-link preview card because the OG metadata
is embedded in each file before any redirect fires.

---

## Keeping mirrors current

The mirror pages reference the GitHub Pages project by URL — they don't embed
its content. When the canonical project is updated and pushed to GitHub Pages,
the mirrors automatically point to the new content without any action on your
part (because all four resource buttons are hard-linked to github.io).

The only time you'd need to re-upload a mirror file is if you change the
headline figures or project description and want the link-preview card to
reflect the update. In that case, edit the relevant `og:description` and
`og:title` tags in the mirror file and re-upload.
