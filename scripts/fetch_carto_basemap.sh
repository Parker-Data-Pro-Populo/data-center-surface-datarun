#!/bin/bash
# Fetch CARTO Voyager basemap for Texas bounding box and stitch into a single PNG.
# Tile math: Web Mercator slippy-map tiles. At zoom Z, world = 2^Z tiles wide.
# TX bbox (lon, lat): SW (-106.65, 25.84) NE (-93.51, 36.50)

set -e

Z=7      # zoom level — gives ~128x128 px / degree, ~3000x2500 final pixels for TX
SW_LON=-106.65; SW_LAT=25.84
NE_LON=-93.51;  NE_LAT=36.50

# lon/lat → tile XY (web mercator)
# x = floor((lon + 180) / 360 * 2^z)
# y = floor((1 - ln(tan(lat) + sec(lat)) / pi) / 2 * 2^z)
lon2x() { python3 -c "import math; print(math.floor((($1)+180.0)/360.0 * 2**${Z}))"; }
lat2y() { python3 -c "import math; lat_rad = math.radians($1); print(math.floor((1.0 - math.log(math.tan(lat_rad) + 1.0/math.cos(lat_rad)) / math.pi) / 2.0 * 2**${Z}))"; }

X_MIN=$(lon2x $SW_LON)
X_MAX=$(lon2x $NE_LON)
# Note: latitude is inverted for tile-y, so NE_LAT → smaller y, SW_LAT → larger y
Y_MIN=$(lat2y $NE_LAT)
Y_MAX=$(lat2y $SW_LAT)

echo "Z=$Z  X=[$X_MIN..$X_MAX]  Y=[$Y_MIN..$Y_MAX]"
N_TILES=$(( (X_MAX-X_MIN+1) * (Y_MAX-Y_MIN+1) ))
echo "Fetching $N_TILES tiles..."

CACHE=/tmp/carto_voyager_tx
mkdir -p $CACHE

# CARTO Voyager (light cartographic, free, no key)
SUBDOMAINS=(a b c d)
i=0
for y in $(seq $Y_MIN $Y_MAX); do
  for x in $(seq $X_MIN $X_MAX); do
    sd=${SUBDOMAINS[$(( (i) % 4 ))]}
    f="$CACHE/${Z}_${x}_${y}.png"
    if [ ! -s "$f" ]; then
      curl -sS --max-time 20 -o "$f" \
        "https://cartodb-basemaps-${sd}.global.ssl.fastly.net/rastertiles/voyager/${Z}/${x}/${y}.png"
    fi
    i=$(( i + 1 ))
  done
done
echo "Tile fetch complete. Stitching..."

# Stitch row-major into a grid via ImageMagick montage
N_COLS=$(( X_MAX - X_MIN + 1 ))
N_ROWS=$(( Y_MAX - Y_MIN + 1 ))
OUT=/tmp/carto_voyager_tx.png

# Build list in row-major order (y outer, x inner)
TILES=""
for y in $(seq $Y_MIN $Y_MAX); do
  for x in $(seq $X_MIN $X_MAX); do
    TILES="$TILES $CACHE/${Z}_${x}_${y}.png"
  done
done
magick montage -tile ${N_COLS}x${N_ROWS} -geometry 256x256+0+0 $TILES "$OUT"
echo "Wrote $OUT ($(file "$OUT" | grep -oE '[0-9]+ x [0-9]+'))"

# Save bbox metadata for georeferencing
cat > /tmp/carto_voyager_tx.bbox <<EOF
Z=$Z
X_MIN=$X_MIN
X_MAX=$X_MAX
Y_MIN=$Y_MIN
Y_MAX=$Y_MAX
NCOLS=$N_COLS
NROWS=$N_ROWS
EOF
echo "Metadata at /tmp/carto_voyager_tx.bbox"
