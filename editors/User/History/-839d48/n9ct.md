Critical
User-facing
#	Issue	Evidence
C1	Timetable & Calendar pages are 404s. pdf_view.html requests /static/timetable.pdf and /static/calendar.pdf, but the files live in static/timetable/timetable.pdf and static/calendar/calendar.pdf.	app.py:185-189, templates/pdf_view.html:136
C2	Department filter silently hides courses. The filter hardcodes ["CSE","ECE","MTH","BIO","DES","SSH","OTHERS"], but CSV Cluster values include CSE  (trailing space), Maths, MATH, MATHS, CSD, ENT, HCD, CB, CSE/ECE. Selecting any filter drops all courses whose cluster isn't in the hardcoded list, and the CSE  vs CSE mismatch breaks the CSE filter.	index.html:260-271, static/Courses.csv
C3	~475-course graph labels only 5-6 departments. dept = code[0:3] turns AI201 → AI2, MTH552B → MTH, ENT309 → ENT, so the Cytoscape color legend (CSE/ECE/MTH/BIO/DES) misses newer depts (AI, ENT, HCD, CSD) — they fall to default styling.	update.py:183,312, howto.md:226-235
Maintainer-facing
#	Issue	Evidence
C4	Heroku deploy is broken. runtime.txt pins Python 3.6.8, but requirements.txt has Flask 3.0.2 (needs ≥3.8) and pandas 2.1.4 (needs ≥3.9) — pip install fails outright on the pinned runtime. The Dockerfile uses 3.12, so the two deploy paths disagree.	runtime.txt, requirements.txt, Dockerfile:1
C5	App crashes at import if CWD ≠ project root. load_embed_links('./static/Courses.csv') and csvFilePath = "./static/Courses.csv" use relative paths at module import time; a different working dir (common with gunicorn/systemd/docker entrypoints) raises FileNotFoundError on startup.	app.py:10-12,61
Moderate
User-facing
#	Issue	Evidence
M1	Data quality in CSV: 15 rows missing Serial Number; Semester has typos Wnter and Mosoon plus Monsoon/Winter (not a valid enum value); 222 rows use empty cells instead of None for prereqs; a row's prereq is free text (One programming course) instead of a course code (shows up as an orphan node/link).	Courses.csv, update.py --validate-only → 230 warnings
M2	Description link relies on a zero-length query key. URL /viewDescription/filename?=CODE is parsed with request.args.get(""). It works, but it's undocumented, fragile, and the route name is misleading. jsongenerator.py even emits hardcoded http://127.0.0.1:5000/... links — if anyone regenerates via the legacy script, all production links break.	app.py:165-179, jsongenerator.py:34
M3	Dead about page returns file_not_found.html, and /timetable, /calendar links are disabled in the directory nav while the (broken) routes still exist.	app.py:183-193, index.html:145-146
Maintainer-facing
#	Issue	Evidence
M4	Repo bloat / hygiene: 96 MB .git; venv/ (346 files), app.pyc/jsongenerator.pyc/preprocessing.pyc, __pycache__/, static/Untitled/ + static/Untitled.zip (a Cytoscape web-session export), temp/Courses.csv, an empty cat file, and bundle.js.backup are all committed. .gitignore misses most of these.	git ls-files
M5	Admin/upload subsystem is half-dead code: ADMIN_LOGGED_IN, all upload routes, preprocessing.py, and login.html/fileUpload.html/pdfUpload.html are commented out/unused but still shipped. app.secret_key = "secret key" is hardcoded.	app.py:19,25,77-163, preprocessing.py
M6	Frontend dependency soup in index.html: DataTables loaded twice (1.10.12 + 1.10.9 jquery.dataTables.js), the rowReorder CSS is loaded via <script type="text/css" src="http://..."> (invalid tag + http mixed-content → never loads), duplicate includes.	index.html:12-23
M7	Cross-listed prereq edges silently dropped: graph edges key on the full code (ENT201/ENT405), so a prereq written as ENT201 won't link to it.	update.py:196,373
Improvements
User-facing
- Feature: link Preferable Prerequisites and Antirequisites in the graph as distinct edge styles (currently only shown as text; the UI tooltip already admits this gap — techtree.html:67).
- Feature: add search/filter by Professor, Semester, and Credits in the directory (currently only cluster checkboxes).
- Add a "Last updated on …" date to the directory and graph pages.
- Use <label>/aria attributes for the filter checkboxes; escape course names/URLs before injecting into table cells (XSS surface via data in format()).
- Surface CSV validation warnings (e.g., typo'd semesters) somewhere visible instead of only in update.py output.
Maintainer-facing
- Refactor: convert the route to /viewDescription/<course_code> and drop the ?=-parsing hack (M2); remove the dead admin code (M5).
- Testing/CI: add a pytest suite for update.py (golden-file comparison of generated JSON), and a GitHub Action that runs update.py --validate-only on every push so bad data never lands.
- Config: move secret_key and the Adobe clientId (pdf_view.html:134) to environment variables; load embed_links lazily or with a try/except.
- Cleanup: git rm venv/pyc/Untitled*/cat/temp; merge howto.md + learntoupdate.md; delete legacy jsongenerator.py/preprocessing.py/winencheese.js/bundle.js.backup; unify on one deploy path (pick Docker or Heroku, not both with conflicting runtimes).
- Make CSV generation canonical: drop the empty first column header, auto-assign serial numbers, and validate Semester/Credits against enums.
- Add a Makefile/entrypoint.sh and switch the Docker CMD to read PORT like the Procfile.


