# Tools, sources and licences

- **Source brief:** `Last Tram Art Guidelines.md`, supplied by the user; copied to `docs/ART_BRIEF.md`.
- **Artwork:** original integer-pixel drawing code in `src/`, created for this project. Terrain, architecture, signs, objects, people and props are drawn directly in JavaScript. The Route B material ramps and skin tones come from the supplied brief. One muted purple hair colour extends the palette to satisfy its hair options.
- **Tools:** JavaScript, Node.js built-ins, a custom PNG encoder using `node:zlib`, and the browser's native Canvas 2D API. Browser verification uses the environment's installed Playwright and Chromium; neither is required to run or build the art kit.
- **Image generation:** not used. No generated raster reference is needed for this first pass.
- **Third-party visual assets, fonts and brands:** none. In-world lettering uses an original 3 × 5 bitmap font. The viewer uses system monospace fonts. Shop names and signs are fictional.

There are no third-party asset licences to inherit. The supplied brief remains the user's source material; this file makes no separate rights claim over it.
