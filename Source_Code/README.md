# CarePark-KR — Smart Parking Access & Space Allocation Reasoning System

CT-351 Knowledge Representation & Reasoning · Complex Computing Problem

A knowledge-based gatekeeper and bay allocator for Car park P at Riverside General
Hospital (4 levels, 13 zones, 29 bays, 8 departments). For every vehicle at the gate it
decides whether to admit it, which bay it gets, what it pays and which alerts follow,
and it explains every answer.

## Numbers
| | |
|---|---|
| Ground facts | 431 |
| Horn rules (decision + monitoring) | 97 (83 + 14) |
| Integrity constraints | 13 |
| Negation strata | 3 |
| Derived facts / cycles (baseline) | 857 / 13 |
| Test scenarios | 22 (all pass) |
| Frames (class / instance) | 30 / 16, 10-scene script |
| Semantic network | 61 nodes, 79 links |
| FOL statements | 36 (21 beyond Horn, model-checked) |
| DL axioms | 89 |
| Automated tests | 159 Prolog + 71 JavaScript |

## Requirements
- SWI-Prolog 9 (https://www.swi-prolog.org)
- Node.js 18+ (only for the JavaScript tests and rebuilding the site)

## Run
```
swipl main.pl                              # menu
swipl main.pl day                          # baseline day: decisions, alerts, fees, ICs
swipl main.pl day tc05                     # any scenario tc01..tc22
swipl main.pl saturate                     # forward chaining trace
swipl main.pl prove "admitted(wv_no)"      # backward chaining trace + proof tree
swipl main.pl whynot "admitted(car_bu)"    # why-not explanation
swipl main.pl scenarios                    # 22 test cases
swipl main.pl frames | net | fol | dl | script | rules | facts | stats
swipl main.pl export                       # regenerate website/*.json
swipl tests/run.pl                         # 159 Prolog tests
node --test tests_js/engine.test.mjs       # 71 JS tests
node tools/build_site.mjs                  # rebuild website/index.html
```
Open `website/index.html` in a browser for the 3D control room (needs internet for
three.js and fonts).

## Layout
- `kb/` facts, rules (as data `r(Id,Head,Body)`), scenarios
- `engine/` forward chainer (core), day replay (allocate), backward chainer, checks,
  frames, semantic network, FOL, DL, stats
- `main.pl` command line
- `tools/` exporter to JSON, site builder
- `tests/`, `tests_js/` automated tests
- `website/` engine.js (JS port), src/ (page, controller, three.js twin), index.html
- `docs/diagrams/` 10 diagrams (PNG + Mermaid source)
- `docs/generated/` trace sheets and outputs produced by the CLI
- `docs/screenshots/` every website view
- `../Report/` the project report (DOCX and PDF); rebuild with `sh tools/build_report.sh`
