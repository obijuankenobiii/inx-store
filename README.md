# Inx Store

One stop shop for inx downloads.

Font packages for Inx are stored under `font/`, with one ZIP per family. Each ZIP contains the original outline files from the source collection, normalized to these style names:

```text
<Family>/Regular.ttf
<Family>/Bold.ttf
<Family>/Italic.ttf
<Family>/BoldItalic.ttf
```

OpenDyslexic keeps its original `.otf` format. The firmware loads both TTF and OTF packages and rasterizes them on demand; there are no 1-bit or 2-bit package variants.

| Package | Family name |
| --- | --- |
| Alegreya | Alegreya |
| AtkinsonHL-Mono | Atkinson Hyperlegible Mono |
| AtkinsonHL-Next | Atkinson Hyperlegible Next |
| BitterPro | Bitter Pro |
| ChareInk7 | ChareInk7SP |
| Charis | Charis |
| Inter | Inter |
| Lexend | Lexend |
| LexicaUltralegible | Lexica Ultralegible |
| Literata | Literata |
| Lora | Lora |
| Merriweather | Merriweather |
| NotoSans | Noto Sans |
| OpenDyslexic | OpenDyslexic |
| PlexMono | IBM Plex Mono |
| PlexSans | IBM Plex Sans |
| SourceSans3 | Source Sans 3 |
| SourceSerif4 | Source Serif 4 SmText |
| Tinos | Tinos |

## Dictionaries

StarDict dictionaries are stored under `dictionary/` as compressed ZIP archives. The firmware
downloads the archive to the SD card and extracts the `.ifo`, `.idx`, `.dict`, and optional `.syn`
files without placing the dictionary in firmware flash or loading the uncompressed dictionary into
RAM as one buffer.

```text
dictionary/oxford.zip  # Oxford English; about 25 MB compressed, about 124 MB extracted
```

## Plugins

Lua plugin packages are stored under `plugin/` and contain a flat package layout so the firmware
installer can validate and extract them safely:

```text
plugin/study-cards.zip  # Anki Export
plugin/series.zip       # Series grouping and next-book suggestions
```
