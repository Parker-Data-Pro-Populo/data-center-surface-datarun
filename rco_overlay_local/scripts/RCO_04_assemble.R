#!/usr/bin/env Rscript
# RCO_04_assemble.R — assemble the channel-decomposed Resource-Competition
# Overlay from the pulled + acquired + hand-coded layers.
#   RCO_channel = D_norm * susceptibility_channel * (1 - mediator_channel)
# Channels kept SEPARATE (multi-loci); a combined view is provided but the
# per-channel surfaces are the primary product.

source("RCO_00_config.R")

rd <- function(f) if (file.exists(file.path(OUT,f)))
  fread(file.path(OUT,f), colClasses=list(character="fips")) else {
  message("MISSING ", f, " — run earlier stage."); NULL }

substrate <- rd("rco_substrate.csv")
chr <- rd("rco_chr.csv"); acs <- rd("rco_acs.csv")
qcew <- rd("rco_qcew.csv"); bea <- rd("rco_bea.csv"); pep <- rd("rco_pep.csv")
D   <- rd("rco_force_D.csv")
gcd <- fread("RCO_03_gcd_pgma_coding.csv", colClasses=list(character="fips"))

# ── Merge to one county table ───────────────────────────────────────────────
dt <- Reduce(function(a,b) merge(a,b,by="fips",all.x=TRUE),
             Filter(Negate(is.null), list(substrate, chr, acs, qcew, bea, pep)))
dt <- merge(dt, gcd[, .(fips,gcd_present,gcd_funding,pgma)], by="fips", all.x=TRUE)
if (!is.null(D)) dt <- merge(dt, D, by="fips", all.x=TRUE)
for (c in c("dc_mw_operating","dc_mw_queued","dc_count_operating"))
  if (c %in% names(dt)) dt[is.na(get(c)), (c) := 0]

# ── Susceptibility composites (national z -> [0,1], averaged within channel) ─
norm01 <- function(x){ z <- scale(x)[,1]; r <- range(z, na.rm=TRUE)
                       (z - r[1]) / (r[2]-r[1]) }
build_channel <- function(dt, spec){
  cols <- names(spec)
  present <- cols[cols %in% names(dt)]
  if (!length(present)) return(rep(NA_real_, nrow(dt)))
  M <- sapply(present, function(cn){
    d <- spec[[cn]]                      # +1 / -1 direction
    norm01(d * as.numeric(dt[[cn]]))
  })
  rowMeans(M, na.rm = TRUE)              # composite in ~[0,1]
}
dt[, sus_water := build_channel(dt, CHANNELS$water)]
dt[, sus_power := build_channel(dt, CHANNELS$power)]
dt[, sus_land  := build_channel(dt, CHANNELS$land)]

# ── Mediator capacity ───────────────────────────────────────────────────────
# Water: graded GCD funding scaled, penalised by PGMA stress. Missing coding
# (e.g., non-TX in first pass) -> 0 capacity (conservative: assume unprotected).
sc <- RCO_PARAMS$gcd_capacity_scale
dt[, med_water := {
  cap <- ifelse(is.na(gcd_funding), 0, sc[as.character(gcd_funding)])
  cap * (1 - RCO_PARAMS$pgma_penalty * fifelse(is.na(pgma),0L,pgma))
}]
# Power/land mediators: regulatory-posture hand-code hook (default 0).
# TODO(Code): optional county moratorium / preemption-posture table.
dt[, med_power := 0]
dt[, med_land  := 0]

# ── Force normalisation (among DC-bearing counties; others -> 0) ────────────
# Prefer MW when available; if MW is uniformly zero (e.g., Comptroller-only
# scrape with no MW data), fall back to facility count as the force proxy.
mw  <- if ("dc_mw_operating"    %in% names(dt)) dt$dc_mw_operating    else rep(0,nrow(dt))
mwq <- if ("dc_mw_queued"       %in% names(dt)) dt$dc_mw_queued       else rep(0,nrow(dt))
cnt <- if ("dc_count_operating" %in% names(dt)) dt$dc_count_operating else rep(0,nrow(dt))
mm01 <- function(x){ pos <- x[x>0]; if(!length(pos)) return(rep(0,length(x)))
  r <- range(pos); ifelse(x>0, (x-r[1])/ifelse(diff(r)==0,1,diff(r)), 0) }
force_basis <- if (sum(mw, na.rm=TRUE) > 0) "mw" else "count"
message("force basis: ", force_basis,
        "  (sum_mw=", sum(mw, na.rm=TRUE),
        ", sum_count=", sum(cnt, na.rm=TRUE), ")")
dt[, D_operating := mm01(if (force_basis == "mw") mw else cnt)]
dt[, D_queued    := mm01(mwq)]
# Use operating as primary; queued is the confidence-flagged upside.
dt[, D := pmax(D_operating, 0.5 * D_queued)]   # tune the 0.5 queued discount

# ── RCO per channel ─────────────────────────────────────────────────────────
dt[, rco_water := D * sus_water * (1 - med_water)]
dt[, rco_power := D * sus_power * (1 - med_power)]
dt[, rco_land  := D * sus_land  * (1 - med_land)]
chcols <- c("rco_water","rco_power","rco_land")
dt[, rco_max := do.call(pmax, c(.SD, na.rm=TRUE)), .SDcols=chcols]
dt[, rco_sum := rowSums(.SD, na.rm=TRUE),          .SDcols=chcols]
dt[, dominant_channel := c("water","power","land")[max.col(
      replace(as.matrix(.SD), is.na(as.matrix(.SD)), -Inf), "first")], .SDcols=chcols]

# ── Outputs ─────────────────────────────────────────────────────────────────
keep <- c("fips","H","k10","rucc","pct_growth_2020_24",
          "sus_water","sus_power","sus_land","med_water","D_operating","D_queued","D",
          chcols,"rco_max","rco_sum","dominant_channel")
keep <- keep[keep %in% names(dt)]
fwrite(dt[, ..keep], file.path(OUT, "rco_surface_national.csv"))

cl1 <- fread(file.path(OUT,"rco_cluster1_fips.csv"))$fips
fwrite(dt[fips %in% cl1, ..keep], file.path(OUT, "rco_surface_cluster1.csv"))

peer <- dt[fips %in% PEER_CLUSTER1, ..keep]
peer <- merge(peer, TX_SET[, .(fips,name)], by="fips", all.x=TRUE)
fwrite(peer, file.path(OUT, "rco_peer_set.csv"))

cat("\n── Peer-set RCO (Parker / Hays / Hood) ──\n")
print(peer[, .(name, growth=pct_growth_2020_24,
               sus_water=round(sus_water,2), sus_power=round(sus_power,2),
               sus_land=round(sus_land,2), med_water=round(med_water,2),
               D=round(D,2), dominant_channel,
               rco_water=round(rco_water,3), rco_power=round(rco_power,3),
               rco_land=round(rco_land,3))])

cat("\nNotes: with no manual DC sites loaded yet, D==0 -> RCO==0 everywhere.",
    "\nPopulate datacenter_sites_manual.csv (RCO_02) to light up the surface.\n")
message("RCO_04 done.")
