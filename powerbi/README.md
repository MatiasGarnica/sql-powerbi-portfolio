# Power BI artifacts

This folder will contain:

| File / Folder | Purpose |
|---|---|
| `*.pbip/` | Power BI Project format (versionable: stores model and report as JSON/TMDL) |
| `measures.dax` | All DAX measures exported via Tabular Editor |
| `m_queries.pq` | Power Query M code from the data source steps |
| `screenshots/` | Static PNG/GIF previews of each report page |

## Why `.pbip` instead of `.pbix`

`.pbix` is a binary archive — useful to open in Power BI Desktop but unreadable
in Git diffs and impossible to review in pull requests. Power BI Project
(`.pbip`) format saves the same content as readable JSON/TMDL files inside a
folder structure, which Git tracks line-by-line.

To save your existing `.pbix` as `.pbip`:
1. Open the `.pbix` in Power BI Desktop
2. **File → Save as → Power BI project file (.pbip)**

This generates a `<name>.pbip` file plus two folders:
`<name>.Report/` and `<name>.SemanticModel/`. Commit all of them.

## Exporting measures and M queries

### DAX measures via Tabular Editor (free, recommended)

1. Download Tabular Editor 2 from [tabulareditor.com](https://tabulareditor.com)
2. Open your `.pbix` (or connect to the running Power BI Desktop instance)
3. Right-click `Tables` in the explorer → **Save All Measures to Disk** →
   save as `measures.dax` in this folder

### M (Power Query) code

In Power BI Desktop:
1. **Transform data** → opens Power Query Editor
2. For each query, right-click → **Advanced Editor** → copy the M code
3. Paste each into a section of `m_queries.pq` with a comment header

## Screenshots

Once the report pages are styled and anonymized:
1. Power BI Desktop → File → Export → PowerPoint (or capture each page as PNG)
2. Crop and save under `screenshots/`
3. Reference them from the main README to give the repo visual impact
