# finds the page of each heading in the rendered PDF and writes report/toc.json
import json, subprocess, sys
heads = json.load(open('report/headings.json'))
pages = {}
n = int([l for l in subprocess.run(['pdfinfo', 'report/CarePark-KR_CCP_Report.pdf'], capture_output=True, text=True).stdout.splitlines() if l.startswith('Pages')][0].split()[1])
txt = [subprocess.run(['pdftotext', '-f', str(i), '-l', str(i), '-layout', 'report/CarePark-KR_CCP_Report.pdf', '-'], capture_output=True, text=True).stdout for i in range(1, n + 1)]
start = 3   # skip cover, rubric, contents
for lv, h in heads:
    for i in range(start, n):
        if any(line.strip() == h for line in txt[i].splitlines()):
            pages[h] = i + 1; start = i; break
json.dump(pages, open('report/toc.json', 'w'), indent=0)
print(len(pages), 'of', len(heads), 'found')
