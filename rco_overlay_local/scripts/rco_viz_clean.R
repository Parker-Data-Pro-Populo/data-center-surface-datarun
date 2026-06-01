#!/usr/bin/env Rscript
# rco_viz_clean.R — redesigned visuals for the RCO project.
# Replaces 07/08/09/10 with cleaner TX-only maps.
suppressPackageStartupMessages({
  library(data.table); library(sf); library(tigris); library(RColorBrewer)
})
options(tigris_use_cache = TRUE)

OUT  <- "~/rco_overlay/output"
VOUT <- "~/rco_overlay/viz"; dir.create(VOUT, recursive=TRUE, showWarnings=FALSE)

nat   <- fread(file.path(OUT, "rco_surface_national.csv"),
               colClasses=list(character="fips"))
sites <- fread(file.path(OUT, "datacenter_sites_manual.csv"),
               colClasses=list(character="county_fips"))
gcd   <- fread("~/rco_run/RCO_03_gcd_pgma_coding.csv",
               colClasses=list(character="fips"))

cnty_raw <- counties(cb=TRUE, resolution="20m", year=2023, progress_bar=FALSE)
cnty_raw <- st_transform(cnty_raw, 3081)   # Texas Centric Lambert (NAD83)
cnty_raw$fips <- paste0(cnty_raw$STATEFP, cnty_raw$COUNTYFP)
tx <- cnty_raw[cnty_raw$STATEFP == "48", ]

# Aggregate sites by county
site_ct <- sites[!is.na(county_fips),
                 .(n=.N, mw=sum(mw, na.rm=TRUE)), by=.(fips=county_fips)]

m <- merge(tx, nat,     by="fips", all.x=TRUE)
m <- merge(m,  site_ct, by="fips", all.x=TRUE)
m <- merge(m,  gcd[, .(fips, gcd_funding)], by="fips", all.x=TRUE)

# ── Palette ────────────────────────────────────────────────────────────────
pal <- list(
  water  = "#2c7fb8",
  power  = "#e6783c",
  land   = "#5da75a",
  unlit  = "#f4f4f2",
  border = "#c8c8c8",
  peer   = "#c0282d",
  gcd_y  = "#9aa6b2"
)
peer   <- c("48367","48209","48221","48217")      # Parker, Hays, Hood, Hill (moratorium)

# Helper: dominant-channel base colour, opacity scaled to RCO_max
chan_col <- function(channel) {
  switch(channel %||% "x",
         water = pal$water, power = pal$power, land = pal$land,
         pal$unlit)
}
`%||%` <- function(a,b) if (!is.na(a) && length(a)) a else b
alpha_hex <- function(hex, a) {
  rgb <- col2rgb(hex)/255
  sprintf("#%02X%02X%02X%02X",
          round(rgb[1]*255), round(rgb[2]*255), round(rgb[3]*255),
          round(a*255))
}
m$is_lit <- !is.na(m$D) & m$D > 0
maxv <- max(m$rco_max, na.rm=TRUE)
m$col_main <- pal$unlit
for (i in which(m$is_lit)) {
  ch <- m$dominant_channel[i]
  base <- switch(ch, water=pal$water, power=pal$power, land=pal$land, pal$unlit)
  # opacity: 0.45 floor so even lowest-RCO lit county is clearly visible
  a <- 0.45 + 0.55 * (m$rco_max[i] / maxv)
  m$col_main[i] <- alpha_hex(base, a)
}

# MW choropleth — log scale, single Reds ramp
mw_breaks <- c(-Inf, 0, 50, 100, 250, 500, 1000, Inf)
mw_pal    <- c(pal$unlit, "#fee5d9", "#fcae91", "#fb6a4a", "#de2d26",
                "#a50f15", "#67000d")
m$mw <- ifelse(is.na(m$mw), 0, m$mw)
m$col_mw <- mw_pal[as.integer(cut(m$mw, mw_breaks, right=TRUE))]

# Labels: only storied counties
label_set <- data.table(
  fips = c("48441","48331","48029","48201","48453","48113","48085",
           "48371","48135","48349","48121","48367","48221","48209","48217"),
  short = c("Taylor","Milam","Bexar","Harris","Travis","Dallas","Collin",
            "Pecos","Ector","Navarro","Denton","Parker","Hood","Hays","Hill")
)

draw_labels <- function(set, m, cex=0.7, peer_col=pal$peer) {
  for (i in seq_len(nrow(set))) {
    p <- m[m$fips == set$fips[i], ]
    if (!nrow(p)) next
    ct <- suppressWarnings(st_centroid(st_geometry(p)))
    xy <- st_coordinates(ct)
    col <- if (set$fips[i] %in% peer) peer_col else "#222222"
    fnt <- if (set$fips[i] %in% peer) 2 else 1
    text(xy[1], xy[2], set$short[i], cex=cex, col=col, font=fnt)
  }
}

# ── (A) Texas RCO surface — channel × opacity ──────────────────────────────
# Labels for A: drop DFW cluster (covered by chart C) to avoid collisions.
a_label <- label_set[!fips %in% c("48367","48221","48113","48085","48121",
                                    "48439","48497","48337","48181","48097",
                                    "48077","48143","48425","48251","48257",
                                    "48397","48139")]
png(file.path(VOUT, "A_tx_rco_surface.png"),
    width=1700, height=1500, res=170)
par(mar=c(2,1,4,1), family="sans")
plot(st_geometry(m), col=m$col_main, border=pal$border, lwd=0.25,
     main="Texas data-center resource-competition surface",
     cex.main=1.3, line=2)
mtext("Fill colour = dominant channel (water · power · land). Opacity = relative RCO_max. Unlit counties = no operating registered facility.",
      side=3, line=0.4, cex=0.88, col="#444444")

# Peer set on top
peer_poly <- m[m$fips %in% peer, ]
plot(st_geometry(peer_poly), col=NA, border=pal$peer, lwd=2.2, add=TRUE)

draw_labels(a_label, m, cex=0.95)

legend("bottomleft",
       legend=c("water — aquifer competition",
                "power — utility / fixed-income burden",
                "land — ag-conversion exposure",
                "no operating facility",
                "Peer set (Parker · Hood · Hays · Hill)"),
       fill=c(pal$water, pal$power, pal$land, pal$unlit, NA),
       border=c(NA,NA,NA,pal$border, pal$peer),
       lwd=c(NA,NA,NA,NA,2.2), pch=c(NA,NA,NA,NA,NA),
       bty="n", cex=1.0,
       title="Dominant channel — opacity ∝ RCO_max",
       title.adj=0, title.cex=1.05)

mtext("104 facilities · 9.3 GW · 24 lit counties · sources: TX Comptroller (2026-04) + curated MW + TWDB GCD map (2019-11)",
      side=1, line=0.7, cex=0.9, col="#666666")
dev.off()

# ── (B) Texas MW concentration ─────────────────────────────────────────────
png(file.path(VOUT, "B_tx_mw_concentration.png"),
    width=1700, height=1500, res=170)
par(mar=c(2,1,4,1), family="sans")
plot(st_geometry(m), col=m$col_mw, border=pal$border, lwd=0.25,
     main="Operating data-center capacity per county",
     cex.main=1.3, line=2)
mtext("Total MW of operating + Comptroller-registered facilities. Two counties carry 41% of TX's operational fleet.",
      side=3, line=0.4, cex=0.88, col="#444444")

# Peer outline on top so it's still visible
plot(st_geometry(peer_poly), col=NA, border=pal$peer, lwd=2.2, add=TRUE)

# Labels for B: drop DFW cluster (Dallas/Collin/Denton) since they cluster
# visually as the dark patch in north-central; keep peer set (Parker/Hood/Hays)
# bold red to anchor the empty-set narrative.
mw_label <- label_set[fips %in% c("48441","48331","48029","48201","48453",
                                   "48371","48135","48349","48367","48221",
                                   "48209")]
draw_labels(mw_label, m, cex=0.95)

legend("bottomleft",
       legend=c("0", "1–49", "50–99", "100–249", "250–499", "500–999", "≥1 000"),
       fill=mw_pal, border=pal$border, bty="n", cex=1.0,
       title="MW operational", title.adj=0, title.cex=1.05)
mtext("Source: TX Comptroller registry + operator press / 10-K MW disclosures (curated).",
      side=1, line=0.7, cex=0.9, col="#666666")
dev.off()

# ── (C) DFW close-up — same encoding as A, dedicated panel ────────────────
dfw_counties <- c(
  "48085",  # Collin
  "48113",  # Dallas
  "48121",  # Denton
  "48139",  # Ellis
  "48181",  # Grayson
  "48251",  # Johnson
  "48257",  # Kaufman
  "48337",  # Montague
  "48367",  # Parker  (peer)
  "48397",  # Rockwall
  "48439",  # Tarrant
  "48497",  # Wise
  "48221",  # Hood    (peer)
  "48425",  # Somervell
  "48143",  # Erath
  "48077",  # Clay
  "48097"   # Cooke
)
dfw <- m[m$fips %in% dfw_counties, ]

png(file.path(VOUT, "C_dfw_closeup.png"),
    width=1500, height=1500, res=180)
par(mar=c(2,1,4,1), family="sans")
plot(st_geometry(dfw), col=dfw$col_main, border=pal$border, lwd=0.35,
     main="DFW close-up — Parker and Hood sit empty inside a lit corridor",
     cex.main=1.3, line=2)
mtext("Tarrant · Dallas · Denton · Collin all host operating facilities. Parker · Hood · Hays · Hill — the peer set — do not.",
      side=3, line=0.4, cex=0.88, col="#444444")

# Peer outlines
peer_dfw <- dfw[dfw$fips %in% peer, ]
plot(st_geometry(peer_dfw), col=NA, border=pal$peer, lwd=2.5, add=TRUE)

# Label every DFW county for readability at this zoom
all_dfw_labels <- data.table(
  fips = dfw$fips,
  short = dfw$NAME
)
draw_labels(all_dfw_labels, m, cex=0.85)

mtext("Source: TX Comptroller registry + TWDB GCD map (2019-11).",
      side=1, line=0.4, cex=0.7, col="#666666")
dev.off()

# ── (D) Refined scatter — clean labels, repositioned legend ────────────────
lit_dt <- as.data.table(nat[D > 0])
lit_dt <- merge(lit_dt, label_set, by="fips", all.x=TRUE)
lit_dt[is.na(short), short := paste0("(", substr(fips,3,5), ")")]
lit_dt[, col := fifelse(dominant_channel == "water", pal$water,
                  fifelse(dominant_channel == "power", pal$power,
                    fifelse(dominant_channel == "land",  pal$land, "#888888")))]

# Custom label nudges for collision avoidance
nudge <- list(
  "48441" = c( 0.06, -0.03),   # Taylor
  "48331" = c(-0.06,  0.00),   # Milam
  "48029" = c(-0.03, -0.04),   # Bexar
  "48201" = c(-0.07,  0.00),   # Harris  (left of point)
  "48453" = c(-0.07,  0.03),   # Travis  (left/up)
  "48371" = c( 0.04,  0.03),   # Pecos   (right/up)
  "48139" = c( 0.05,  0.00),   # Ellis
  "48135" = c(-0.05,  0.00),   # Ector
  "48349" = c( 0.04, -0.04),   # Navarro
  "48113" = c( 0.04, -0.03),   # Dallas
  "48085" = c( 0.04,  0.04),   # Collin
  "48121" = c( 0.04, -0.03)    # Denton
)

png(file.path(VOUT, "D_sus_force_scatter.png"),
    width=1700, height=1200, res=180)
par(mar=c(5,5,3,2), family="sans")
plot(lit_dt$D, lit_dt$sus_water,
     xlab="Force-D  (MW-weighted, 0 → 1)",
     ylab="Water-channel susceptibility (z-norm → 0..1)",
     main="Where TX data centers collide with vulnerability — and where they don't",
     xlim=c(0, 1.10), ylim=c(0, 1),
     pch=21, cex=1.9, bg=lit_dt$col, col="white", lwd=1.5,
     cex.main=1.05, font.main=1)

# Reference lines + zone shading
rect(0.5, 0.5, 1.10, 1.0, col="#fff2f0", border=NA)
points(lit_dt$D, lit_dt$sus_water,
       pch=21, cex=1.9, bg=lit_dt$col, col="white", lwd=1.5)

# Labels with nudges
for (i in seq_len(nrow(lit_dt))) {
  x <- lit_dt$D[i]; y <- lit_dt$sus_water[i]
  short <- lit_dt$short[i]
  if (grepl("^\\(", short)) next                # skip tiny anonymous dots
  nx <- nudge[[lit_dt$fips[i]]]
  if (is.null(nx)) nx <- c(0.025, 0)
  text(x + nx[1], y + nx[2], short, cex=0.82, col="#222222")
  # leader line if nudge is large
  if (abs(nx[1]) > 0.04 || abs(nx[2]) > 0.025) {
    segments(x, y, x + nx[1]*0.6, y + nx[2]*0.6,
             col="#bbbbbb", lwd=0.6)
  }
}

abline(h=0.5, lty=3, col="#aaaaaa"); abline(v=0.5, lty=3, col="#aaaaaa")
text(1.07, 0.97, "high force ×\nhigh vulnerability", cex=0.78, col="#c0282d",
     adj=c(1, 1))
legend("bottomright",
       legend=c("water-dominant", "power-dominant", "land-dominant"),
       pch=21, pt.bg=c(pal$water, pal$power, pal$land), col="white",
       pt.cex=1.5, bty="n", cex=0.85, title="Dominant channel")
mtext("Taylor (1.6 GW Lancium Abilene / Stargate) is the only county in the upper-right with no GCD. The pink quadrant = the unprotected crisis zone.",
      side=1, line=3.5, cex=0.78, col="#444444")
dev.off()

# ── (E) Time-series with cumulative MW ─────────────────────────────────────
sites[, eff_year := as.integer(substr(status_date, 7, 10))]
yr <- sites[!is.na(eff_year), .(n=.N, mw=sum(mw, na.rm=TRUE)),
            by=eff_year][order(eff_year)]
yr[, cum_mw := cumsum(mw)]

png(file.path(VOUT, "E_registration_timeseries.png"),
    width=1700, height=1000, res=180)
par(mar=c(4,4.5,3,4.5), family="sans")
bp <- barplot(yr$n, names.arg=yr$eff_year,
              col="#4a8cc0", border=NA, las=1,
              ylim=c(0, max(yr$n)*1.15),
              main="Texas data-center registrations — the AI buildout shoulder",
              ylab="New registrations per year", cex.names=0.85, cex.main=1.05,
              font.main=1)
text(bp, yr$n, yr$n, pos=3, cex=0.78, col="#222222")

# AI-boom marker
v_idx <- which(yr$eff_year == 2024)
v_x   <- (bp[v_idx] + bp[v_idx - 1])/2
abline(v=v_x, lty=2, lwd=1.5, col="#c0282d")
text(v_x, max(yr$n)*0.95, " AI buildout begins",
     col="#c0282d", cex=0.85, pos=4)

# Cumulative MW on right axis
par(new=TRUE)
plot(bp, yr$cum_mw, type="l", lwd=2.5, col="#a50f15",
     axes=FALSE, xlab="", ylab="",
     ylim=c(0, max(yr$cum_mw)*1.05))
points(bp, yr$cum_mw, pch=21, bg="#a50f15", col="white", cex=1.1)
axis(4, las=1, col="#a50f15", col.axis="#a50f15", cex.axis=0.85)
mtext("Cumulative MW (right axis)", side=4, line=3, col="#a50f15", cex=0.9)

mtext("Bars = new registrations per year. Line = cumulative operating capacity. 75 of 130 facilities registered in 2024-2026.  2026 is YTD through May.",
      side=1, line=2.5, cex=0.78, col="#444444")
dev.off()

cat("\nWrote clean visuals to ", VOUT, ":\n", sep="")
for (f in c("A_tx_rco_surface.png","B_tx_mw_concentration.png",
            "C_dfw_closeup.png","D_sus_force_scatter.png",
            "E_registration_timeseries.png"))
  cat("  ", file.path(VOUT,f), "  ",
      round(file.info(file.path(VOUT,f))$size/1024,1), " KB\n", sep="")
