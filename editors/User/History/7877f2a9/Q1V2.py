import os
import csv
# from jsongenerator import generate_tableJson, generate_graphJson
from preprocessing import check_csv_format
#import urllib.request
from flask import Flask, flash, request, redirect, render_template, url_for
from werkzeug.utils import secure_filename
port = int(os.environ.get("PORT",5000))

csvFilePath = "./static/Courses.csv"
tableJsonFilePath = "./static/Courses.json"
graphJsonFilePath = "./static/graph.json"

UPLOAD_PDF_FOLDER = './static/files/'
UPLOAD_CSV_FOLDER = './static/'
UPLOAD_TEMP_CSV_FOLDER = './temp/'

app = Flask(__name__)
app.secret_key = "secret key"
app.config['UPLOAD_TEMP_CSV_FOLDER'] = UPLOAD_TEMP_CSV_FOLDER
app.config['UPLOAD_PDF_FOLDER'] = UPLOAD_PDF_FOLDER

ALLOWED_FILE_UPLOAD_EXTENSIONS = set(['csv'])
ALLOWED_PDF_UPLOAD_EXTENSIONS = set(['pdf'])
ADMIN_LOGGED_IN = True

# READ EMBED CSV FILE TO GENERATE DICTIONARY:
# KEY = COURSE CODE UPTO FIRST '/'
# VALUE = EMBED IFRAME LINK

embed_links = {}
import re

def load_embed_links(csv_path):
	"""Builds {course_code: embed_link_html} from Courses.csv.

	Uses DictReader (column-name based) instead of positional indexing, so
	this doesn't silently break if a column is ever reordered, and doesn't
	need the raw csv.reader loop that was previously also processing the
	header row itself as if it were a data row.
	"""
	links = {}
	with open(csv_path, mode='r') as infile:
		reader = csv.DictReader(infile)
		for row in reader:
			raw_code = row.get('Course Code') or ''
			if not raw_code.strip():
				continue
			course_code = re.sub(r'\s+', '', raw_code.split('/')[0])
			embed_link_value = row.get('embed_link', '')
			if course_code in links:
				# Courses.csv currently has a few duplicate course codes;
				# keep the first entry rather than silently letting a later,
				# unrelated course overwrite an earlier one's description link.
				print(f"Warning: duplicate course code '{course_code}' in Courses.csv "
					  f"- keeping the first embed link, ignoring later ones.")
				continue
			links[course_code] = embed_link_value
	return links

embed_links = load_embed_links('./static/Courses.csv')

# print(embed_links)

@app.after_request
def add_header(r):
    """
    Add headers to both force latest IE rendering engine or Chrome Frame,
    and also to cache the rendered page for 10 minutes.
    """
    r.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    r.headers["Pragma"] = "no-cache"
    r.headers["Expires"] = "0"
    r.headers['Cache-Control'] = 'public, max-age=0'
    return r

# def allowed_csv_file(filename):
# 	return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_FILE_UPLOAD_EXTENSIONS

# def allowed_pdf_file(filename):
# 	return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_PDF_UPLOAD_EXTENSIONS
	
@app.route('/')
def tech_table():
	return render_template('index.html')

# @app.route('/testing')
# def render_cise():
# 	return render_template('demo_cise.html')

# @app.route('/admin/login')
# def login():
# 	return render_template('login.html')

@app.route('/techtree')
def tech_tree():
	return render_template('techtree.html')

@app.route('/credits')
def render_credits():
	return render_template('credits.html')

@app.route('/contact')
def contact_us():
	return render_template('contact.html')

# @app.route('/admin/login')
# def render_login_page():
# 	ADMIN_LOGGED_IN = True
# 	return render_template('admin_login_page.html')

# @app.route('/admin/logout')
# def log_out_admin():
# 	ADMIN_LOGGED_IN = False
# 	return render_template('logged_out.html')

# @app.route('/upload_csv')
# def render_csv_upload_page():
# 	return render_template('fileUpload.html')

# @app.route('/upload_csv', methods=['POST'])
# def upload_csv_file():
# 	if request.method == 'POST' and ADMIN_LOGGED_IN:
#         # check if the post request has the files part
# 		if 'files[]' not in request.files:
# 			flash('No file part')
# 			return redirect(request.url)
# 		files = request.files.getlist('files[]')
# 		for file in files:
# 			if file and allowed_csv_file(file.filename):
# 				filename = secure_filename(file.filename)
# 				file.save(os.path.join(app.config['UPLOAD_TEMP_CSV_FOLDER'], filename))
# 				result = check_csv_format()
# 				if(result[0]==False):
# 					os.system('mv ./temp/Courses.csv ./static/')
# 					generate_tableJson();
# 					generate_graphJson();
# 				for i in range(0,len(result[1])):
# 					flash(result[1][i])
# 			else:
# 				flash("Incorrect file extension. Only CSV file can be uploaded.")
# 		return redirect(url_for('render_csv_upload_page'))

# @app.route('/upload_pdf')
# def render_pdf_upload_page():
# 	return(render_template('pdfUpload.html'))

# @app.route('/upload_pdf', methods=['POST'])
# def upload_pdf_file():
# 	if request.method == 'POST':
#         # check if the post request has the files part
# 			if 'files[]' not in request.files:
# 				flash('No file part')
# 				return redirect(request.url)
# 			files = request.files.getlist('files[]')
# 			for file in files:
# 				if file and allowed_pdf_file(file.filename):
# 					filename = secure_filename(file.filename)
# 					file.save(os.path.join(app.config['UPLOAD_PDF_FOLDER'], filename))
# 					flash('File(s) successfully uploaded')
# 				else:
# 					flash("Incorrect file extension. Only PDF(s) can be uploaded.")
# 			return redirect(url_for('render_pdf_upload_page'))

@app.route('/viewDescription/filename', methods=['POST','GET'])
def render_pdf_viewer():
	filename = request.args.get("").replace(" ", "")
	page_title = filename+': Course Description'
	if(filename in embed_links):
		# Previously: embed_links[filename][13:-11], a hardcoded slice that
		# assumed the iframe HTML was formatted as exactly
		# `<iframe src="...">...` with no attribute reordering or extra
		# whitespace. This pulls the URL out properly instead.
		match = re.search(r'src="([^"]+)"', embed_links[filename])
		if not match:
			return render_template('file_not_found.html')
		file_path = match.group(1)
		return render_template('sheet_view.html', description_link=file_path, titlename=page_title)
	return render_template('file_not_found.html')
	# filename = "./files/"+filename+".pdf"
	# return render_template('pdf_view.html', pdf=filename, titlename=page_title)

@app.route('/timetable')
def timetable():
	return render_template('pdf_view.html', pdf="timetable.pdf", titlename="IIITD | TimeTable")

@app.route('/calendar')
def calendar():
	return render_template('pdf_view.html', pdf="calendar.pdf", titlename="IIITD | Calendar")

@app.route('/about')
def about():
	return render_template('file_not_found.html')

@app.errorhandler(404)
def file_not_found(error):
	return render_template('file_not_found.html')

if __name__ == "__main__":
    app.run(debug=True)