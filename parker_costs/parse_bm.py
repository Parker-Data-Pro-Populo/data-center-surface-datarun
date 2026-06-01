import os, re, glob, json

txtdir = "bm_txt"
rows = []

for f in sorted(glob.glob(os.path.join(txtdir, "*.txt"))):
    with open(f) as fh:
        text = fh.read()
    # Some PDFs have an original AND a corrected notice. Capture both views.
    # We split on "NOTICE OF APPRAISED VALUE" headers — each chunk is one notice.
    chunks = re.split(r"\bNOTICE OF APPRAISED VALUE\b", text)
    # First chunk before any header is preamble; subsequent are each notice (header was consumed)
    notices = []
    for i, chunk in enumerate(chunks):
        if i == 0:
            continue
        is_corrected = "CORRECTED" in chunk
        # Property ID
        pid = re.search(r"PROPERTY ID:\s*(\S+)\s*/\s*GEO ID:\s*(\S+)", chunk)
        if not pid:
            continue
        prop_id = pid.group(1)
        geo_id  = pid.group(2)
        # Street + legal
        addr = re.search(r"Street Address:\s*([^\n]+)", chunk)
        legal = re.search(r"Legal Description:\s*([^\n]+)", chunk)
        street = addr.group(1).strip() if addr else ""
        legal_desc = legal.group(1).strip() if legal else ""
        # Acres
        ac = re.search(r"ACRES:\s*([\d.]+)", legal_desc)
        acres = float(ac.group(1)) if ac else None
        # Valuation block — look for LAND MARKET line then numbers
        val_re = re.search(
            r"LAND MARKET\s+([\d,\-]+)\s+([\d,\-]+).*?"
            r"TOTAL MARKET\s+([\d,\-]+)\s+([\d,\-]+).*?"
            r"PRODUCTION LOSS\s+(-?[\d,]+)\s+(-?[\d,]+).*?"
            r"TOTAL APPRAISED\s+([\d,]+)\s+([\d,]+)", chunk, re.DOTALL)
        def n(x): return int(x.replace(",","").replace("-","-")) if x else None
        if val_re:
            ly_land   = n(val_re.group(1)); ty_land   = n(val_re.group(2))
            ly_total  = n(val_re.group(3)); ty_total  = n(val_re.group(4))
            ly_prodls = n(val_re.group(5)); ty_prodls = n(val_re.group(6))
            ly_apprd  = n(val_re.group(7)); ty_apprd  = n(val_re.group(8))
        else:
            ly_land=ty_land=ly_total=ty_total=ly_prodls=ty_prodls=ly_apprd=ty_apprd=None
        # Sum of tax-based-on-last-year column at the bottom of notice
        # Look for the equals line pattern with totals; tax-based-on-last-year is final column.
        tax_total = re.search(r"=========\s+([\d,]+\.\d+)", chunk)
        tax_amt = float(tax_total.group(1).replace(",","")) if tax_total else None
        # ISD detection (which "I.S.D." appears in taxing entities)
        isd_m = re.search(r"\b(WE|AL|SP|AZ|BR|PE|MI|PO|GA)\s*-\s*([A-Z]+\s*I\.S\.D\.)", chunk)
        isd = isd_m.group(1) if isd_m else "?"
        notices.append(dict(
            file=os.path.basename(f),
            notice_type="CORRECTED" if is_corrected else "ORIGINAL",
            prop_id=prop_id, geo_id=geo_id,
            street=street, legal=legal_desc, acres=acres,
            isd=isd,
            ly_land=ly_land, ty_land=ty_land,
            ly_apprd=ly_apprd, ty_apprd=ty_apprd,
            ty_prodls=ty_prodls,
            tax_at_ly_rate=tax_amt,
        ))
    rows.extend(notices)

# Print as table
print(f"\nParsed {len(rows)} notices across {len(set(r['prop_id'] for r in rows))} parcels\n")
print(f"{'Parcel':10} {'Type':9} {'ISD':3} {'Acres':>7} {'Land $':>12} {'Apprd $':>12} {'Tax (LY rate)':>14}  Address")
print("-"*110)
for r in sorted(rows, key=lambda r:(r['prop_id'], r['notice_type'])):
    land = f"{r['ty_land']:,}" if r['ty_land'] else "—"
    apprd = f"{r['ty_apprd']:,}" if r['ty_apprd'] else "—"
    tax = f"${r['tax_at_ly_rate']:,.0f}" if r['tax_at_ly_rate'] else "—"
    ac = f"{r['acres']:.2f}" if r['acres'] else "—"
    print(f"{r['prop_id']:10} {r['notice_type']:9} {r['isd']:3} {ac:>7} {land:>12} {apprd:>12} {tax:>14}  {r['street'][:35]}")

# Aggregate corrected-only
print("\n\n=== CORRECTED notices only (the live 2026 picture) ===")
corrected = [r for r in rows if r['notice_type'] == 'CORRECTED']
# If a parcel has only ORIGINAL, fall back to that
parcels_seen = set(r['prop_id'] for r in corrected)
for r in rows:
    if r['notice_type'] == 'ORIGINAL' and r['prop_id'] not in parcels_seen:
        corrected.append(r)
        parcels_seen.add(r['prop_id'])

total_acres = sum((r['acres'] or 0) for r in corrected)
total_land = sum((r['ty_land'] or 0) for r in corrected)
total_apprd_pre = sum((r['ty_apprd'] or 0) for r in corrected)
total_tax = sum((r['tax_at_ly_rate'] or 0) for r in corrected)
n_parcels = len(corrected)
print(f"\nParcels:       {n_parcels}")
print(f"Total acres:   {total_acres:,.2f}")
print(f"Total land $:  ${total_land:,}")
print(f"Total appraised after corrected notice: ${total_apprd_pre:,}")
print(f"2026 tax (last-year rate): ${total_tax:,.0f}")

# Save CSV
import csv
with open("bm_parcels_2026.csv","w",newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
    w.writeheader()
    for r in rows: w.writerow(r)
print("\nWrote bm_parcels_2026.csv")
