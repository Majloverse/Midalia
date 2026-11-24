# Credits

The map of Milan (`world/milan/`) is built by `world/milan/build_map.py` from open data, changed to fit the game:

- **Buildings, streets, pavements and trees:** Comune di Milano, Database Topografico (DBT) 2020,
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Fetched by `world/milan/get_dbt.sh`.
- **Roof shapes and tree heights:** LiDAR data (c) Ministero dell'Ambiente e della Sicurezza Energetica (MASE),
  Piano Straordinario di Telerilevamento Ambientale, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
  Fetched by `world/milan/get_lidar.py`.
- **Roof colours:** Ortofoto AGEA 2024, Agenzia per le Erogazioni in Agricoltura (AGEA),
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Fetched by `world/milan/get_ortho.py`.
- **Newer buildings, parks, water, footpaths, and where the doors and lamps go:** Map data (c) OpenStreetMap contributors,
  [ODbL](https://opendatacommons.org/licenses/odbl/).

All of it is modified: shapes are simplified, heights measured from the street, roofs rebuilt from the laser survey,
and colours rounded to a few. Façades are drawn by a shader and are not the real ones.
