# Protocol Lunaris

**NASA Space Apps Challenge 2026 · Lunar Landing Site Navigator · Team Devoradores de PA**

Protocol Lunaris is an educational decision-support tool for comparing lunar landing sites and dates.
Pick a landing date and a mission length, and it shows, for 14 lunar sites, where the Sun and Earth sit
against the real horizon, how many hours each stays visible, the longest stretch without each, and
whether the site meets three example requirements. One click delays the landing by 7 days.

## Run it

- **In the browser:** https://houxxie.github.io/Project-Lunaris/
- **Windows:** download [`downloads/ProtocoloLunaris_windows.zip`](downloads/ProtocoloLunaris_windows.zip),
  extract it and run `ProtocoloLunaris.exe`. Windows may show a warning for unsigned programs:
  choose "More info" and then "Run anyway".

Sound starts after the first click on the page.

## What is in this repository

| Folder | Content |
|---|---|
| `docs/` | Web build of the program (served by GitHub Pages) |
| `source/ProtocoloLunaris/` | The complete Godot 4.7 project: code (GDScript), data, images, sounds, tests |
| `source/ProtocoloLunaris/Data/` | Precomputed data read by the program (JSON) |
| `downloads/` | Windows build |

## How it works

- **Sun and Earth positions:** NASA/JPL Horizons (DE441), apparent azimuth and elevation seen from each
  site, hourly from 14 Nov 2026 to 14 Nov 2027, with no atmospheric refraction. Lunar libration is included.
- **Real terrain horizon:** for the 11 south pole sites, the horizon in 1,440 directions computed from
  LRO LOLA elevation maps (5 m, 20 m and 80 m per pixel), with exact 3D geometry on the lunar sphere.
  A body counts as visible when its center is above the terrain, for an observer 2 m above the ground.
- **Candidate regions:** outlines of the nine regions NASA selected in October 2024 for the first crewed
  south pole landing (then planned as Artemis III; NASA now plans that landing as Artemis IV, in 2028),
  from a USGS data release. Each region is represented by one sample point chosen with a fixed rule;
  these are sample points, not landing sites.
- **Requirements:** at most 48 h without the Sun, at most 72 h without Earth, and the Sun and Earth
  visible together at least 60% of the mission. They are team demonstration assumptions, not NASA criteria.
- **Validation:** results were compared with Glaser et al. (2018) and with the LOLA illumination and
  Earth visibility maps of Mazarico et al. (2011). Automated tests in `source/ProtocoloLunaris/Testes/`
  check the numbers shown by the program against reference values computed in Python.

## Limitations

- Hourly data; times are in UTC and shown to the hour.
- Visibility uses the center of the Sun or Earth.
- Apollo 11, Chandrayaan-3 and Chang'e-4 use a flat 0° horizon (no terrain).
- No solar panel, battery, antenna or radio link model: the tool reports sunlight hours and geometric
  Earth visibility, not power or guaranteed communication.
- Educational tool. It does not certify landing sites.

## Data and references

- NASA/JPL Horizons System: https://ssd.jpl.nasa.gov/horizons/
- LRO LOLA south pole topography (NASA/GSFC PGDA product 78): https://pgda.gsfc.nasa.gov/products/78
- LRO LOLA polar elevation maps (NASA PDS): https://pds-geosciences.wustl.edu/lro/lro-l-lola-3-rdr-v1/lrolol_1xxx/data/lola_gdr/polar/img/
- LRO LOLA polar illumination maps (NASA/GSFC PGDA product 69): https://pgda.gsfc.nasa.gov/products/69
- NASA Moon Trek (LRO WAC global mosaic): https://trek.nasa.gov/moon/
- LROC landing site coordinates: https://www.lroc.asu.edu/
- NASA NSSDC Apollo landing site coordinates: https://nssdc.gsfc.nasa.gov/planetary/lunar/lunar_sites.html
- USGS, McClernan (2024), candidate region outlines: https://doi.org/10.5066/P1MEQ6UK
- Canadian Space Agency, Moon Exploration: https://www.asc-csa.gc.ca/eng/astronomy/moon-exploration/
- Glaser et al. (2018): https://doi.org/10.1016/j.pss.2017.07.006
- Barker et al. (2021): https://doi.org/10.1016/j.pss.2020.105119
- Mazarico et al. (2011): https://doi.org/10.1016/j.icarus.2010.10.030

## Use of AI

AI coding assistance (Claude, by Anthropic) was used for parts of the data-processing code, the Godot
interface code and the Portuguese and Spanish translations, following the team's specification and
reviewed by the team. Every number on screen comes from NASA data and fixed rules, not from generative
AI. Details are in [`source/ProtocoloLunaris/USO_DE_IA.md`](source/ProtocoloLunaris/USO_DE_IA.md) (in Portuguese).

## Tools

Godot Engine 4.7 (GDScript) for the program; Python (NumPy, Pillow, Matplotlib) for the data pipeline.
