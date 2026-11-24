#!/bin/sh
# Downloads the Comune di Milano's topographic database, DBT 2020 (CC BY 4.0, 597 MB), and unzips the layers
# build_map.py reads into sources/dbt/shp/. Resumes a cut-short download.
set -e
cd "$(dirname "$0")"
mkdir -p sources/dbt/shp
curl -fL -C - -A "midalia-map-build/1" -o sources/dbt/DBT_2020.zip \
    https://gisportal.comune.milano.it/download/area_download/SIT/DBT2020/DBT_2020.zip
unzip -o -j -q sources/dbt/DBT_2020.zip "DBT 2020 - SHAPE/UN_VOL.*" "DBT 2020 - SHAPE/EDIFC.*" \
    "DBT 2020 - SHAPE/AC_VEI.*" "DBT 2020 - SHAPE/AC_PED.*" "DBT 2020 - SHAPE/ALBERO.*" -d sources/dbt/shp
