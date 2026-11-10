#!/bin/sh
# node tools/build_report.js twice: the second pass fills the contents page numbers
set -e
cd "$(dirname "$0")/.."
for pass in 1 2; do
  node tools/build_report.js
  (cd report && rm -f CarePark-KR_CCP_Report.pdf && soffice --headless --convert-to pdf CarePark-KR_CCP_Report.docx >/dev/null 2>&1)
  python3 tools/report_pages.py
done
