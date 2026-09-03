# Mirror deployment instructions

**Revised 2026-09-02.** There is now one approach, not two: both domains point at the
read-only GitHub Pages site. The self-contained landing pages that used to live here
(`henrylee_index.html`, `texascrossroads_index.html`) have been removed — they were a second
copy of the content, and a second copy is a second thing to correct when a figure changes.
They are recoverable from git history if ever needed.

## Canonical URLs

| What | URL |
|---|---|
| The briefing (current) | `https://parker-data-pro-populo.github.io/data-center-surface-datarun/` |
| The briefing deck | `https://parker-data-pro-populo.github.io/data-center-surface-datarun/slides/` |
| **The June 2026 version, archived** | `https://parker-data-pro-populo.github.io/data-center-surface-datarun/archive/2026-06/` |
| Interactive map | `https://parker-data-pro-populo.github.io/data-center-surface-datarun/viz/tx_rco_interactive.html` |
| Position statement | `https://parker-data-pro-populo.github.io/data-center-surface-datarun/STATEMENT.html` |

The archive URL is stable and safe to link from either domain. The page carries a banner
explaining that it is superseded and links back to the current briefing, so a visitor who
arrives there from an old post or a citation is never left thinking it is current.

## Deploy

| Domain | File | Path on server |
|---|---|---|
| henrylee.vote | `henrylee_redirect.html` | `/parker/index.html` → `henrylee.vote/parker` |
| texascrossroads.net | `texascrossroads_redirect.html` | `/parker/index.html` → `texascrossroads.net/parker` |

Both files fire a `<meta http-equiv="refresh">` and a JS `window.location.replace()`
immediately, so a visitor never sees the redirect page. Each carries OG/Twitter metadata
pointing at its own domain, so a link preview on Facebook, Bluesky, iMessage or Slack renders
the card and shows `henrylee.vote/parker` or `texascrossroads.net/parker` as the source before
the redirect fires.

## When a figure changes

Nothing to redeploy. The domains hold redirects only, so correcting the briefing corrects what
both domains serve. That is the point of the change: in June the same numbers lived in four
places, and when the cost figures were corrected, the mirrors had to be found and corrected too.

The one thing to check after a correction: the OG `description` in both redirect files, since
that text is copied rather than linked. It currently reads "Revised September 2026: the county
has refused abatements, the state has frozen data-center interconnections, and no capacity has
been filed."
