import csv , json
import pandas as pd
csvFilePath = "./static/Courses.csv"
tableJsonFilePath = "./static/Courses.json"
graphJsonFilePath = "./static/graph.json"
cytoscapeFilePath = "./static/networks.json"
graphJsFilePath = "./static/winencheese.js"

coursetocode = {}

def generate_tableJson():
	TechTable_courses = []
	with open (csvFilePath) as csvFile:
		csvReader = csv.DictReader(csvFile)
		for csvRow in csvReader:
			course_code = list(csvRow["Course Code"].split("/"))[0]
			csvRow["Link"]="http://127.0.0.1:5000/viewDescription/filename?="+course_code
			TechTable_courses.append(csvRow)
	for i in range(0,len(TechTable_courses)):
		TechTable_courses[i]['Course Name']+=' # '
		TechTable_courses[i]['Course Name']+=TechTable_courses[i]['Link']
		TechTable_courses[i]['Prerequisites']=TechTable_courses[i]['Prerequisites'].replace('"','')
		TechTable_courses[i]['Preferable_Prerequisites']= " " + TechTable_courses[i]['Preferable_Prerequisites'].replace('"','')
		TechTable_courses[i]['Antirequisites']=TechTable_courses[i]['Antirequisites'].replace('"','')
	with open(tableJsonFilePath, "w") as jsonFile:
		jsonFile.write('{"data": ')
		jsonFile.write(json.dumps(TechTable_courses, indent = 4))
		jsonFile.write("}")
		jsonFile.close()


def generate_graphJson():
	data = pd.read_csv(csvFilePath)
	data = data.to_dict()
	nodes = pd.DataFrame()
	name = []
	ID = []
	cluster = []
	prereqs = []
	names = data['Course Name']
	codes = data['Course Code']
	ids = data['Serial Number']
	clusters = data['Cluster']
	prerequisites = data['Prerequisites']
	for entry in range(0,len(prerequisites)):
		if(isinstance(prerequisites[entry], float)):
			prerequisites[entry] = 'None'
		prerequisites[entry] = prerequisites[entry].replace("'","")
		prerequisites[entry] = prerequisites[entry].replace('"',"")
		prerequisites[entry] = prerequisites[entry].replace(" ", "")
		prerequisites[entry] = list(prerequisites[entry].split(","))
	for i in range(0,len(names)):
		name.append(codes[i]+":"+names[i])
		ID.append(i+1)
		cluster.append(clusters[i])
		prereqs.append(prerequisites[i])
	nodes = '"nodes":[\n'
	for node in range(0,len(names)-1):
		coursetocode[codes[node]] = str(ID[node])
		nodes+='{"data":{"id":"'+str(ID[node])+'","label":"'+codes[node]+'","dept":"'+codes[node][0:3]+'"}'+'},\n'
	coursetocode[codes[node+1]] = str(ID[node+1])
	nodes+='{"data":{"id":"'+str(ID[node+1])+'","label":"'+codes[node+1]+'","dept":"'+codes[node+1][0:3]+'"}'+'}\n],\n'
	print(coursetocode)
	edges = '"edges":[\n'
	edge_count = ID[-1]+1
	for course in range(0, len(names)):
		for prereq in range(0, len(prerequisites[course])):
			if(prerequisites[course][prereq]!='None'):
				print("course", course ,codes[course], names[course], "prereqs", [prerequisites[course][prereq]])
				if(prerequisites[course][prereq] in coursetocode):
					edges+='{"data":{"id":"'+str(edge_count)+'","source":"'+coursetocode[prerequisites[course][prereq]]+'","target":"'+str(course+1)+'"}'+'},\n'
					edge_count+=1
	edges = edges[:-2]
	edges+='\n]\n'
	graphJSON = '{"elements":{\n'+nodes+edges+'}'+'}'
	with open(graphJsonFilePath, "w") as jsonFile:
		jsonFile.write(graphJSON)
		jsonFile.close()

def extract_positions():
	data = pd.read_csv(csvFilePath)
	num_courses = len(data['Serial Number'])
	# num_courses = 278
	x = []
	y = []
	for i in range(0,num_courses):
		x.append(0)
		y.append(0)

	with open(cytoscapeFilePath) as f:
		data = json.load(f)

	for k in range(0,num_courses):
		node_id = int(data['graph.json']['elements']['nodes'][k]['data']['id_original']) - 1
		# print(node_id)
		x[node_id] = float(data['graph.json']['elements']['nodes'][k]['position']['x'])
		y[node_id] = float(data['graph.json']['elements']['nodes'][k]['position']['y'])
	return(x,y)

def generate_layout_graphJson(x,y):
	data = pd.read_csv(csvFilePath)
	data = data.to_dict()
	nodes = pd.DataFrame()
	name = []
	ID = []
	prereqs = []
	creds = []
	sem = []
	prof = []
	names = data['Course Name']
	codes = data['Course Code']
	ids = data['Serial Number']
	credits = data['Credits']
	semester = data['Semester']
	professor = data['Professor']
	prerequisites = data['Prerequisites']
	for entry in range(0,len(prerequisites)):
		if(isinstance(prerequisites[entry], float)):
			prerequisites[entry] = 'None'
		prerequisites[entry] = prerequisites[entry].replace("'","")
		prerequisites[entry] = prerequisites[entry].replace('"',"")
		prerequisites[entry] = prerequisites[entry].replace(" ", "")
		prerequisites[entry] = list(prerequisites[entry].split(","))
		#print(prerequisites[entry])
		for alt2 in range(0,len(prerequisites[entry])):
			prerequisites[entry][alt2] = list(prerequisites[entry][alt2].split("or"))
		#print(prerequisites[entry])
	for i in range(0,len(names)):
		name.append(names[i])
		ID.append(i+1)
		prereqs.append(prerequisites[i])
		creds.append(credits[i])
		sem.append(semester[i])
		prof.append(professor[i])
	nodes = 'nodes:[\n'
	for node in range(0,len(names)-1):
		coursetocode[codes[node]] = str(ID[node])
		nodes += '{data:{id:"'+str(ID[node])+'", selected: !1, cytoscape_alias_list:["'+str(name[node])+'"], canonicalName:"'+str(name[node])+'", SUID:'+str(ID[node])+', NodeType:"'+str(codes[node][0:3])+'", CourseCode: "'+str(codes[node])+'", Prof: "'+str(prof[node])+'", Semester: "'+str(sem[node])+'", credits: "'+str(int(creds[node]))+'", name: "'+str(name[node])+'", shared_name: "'+str(name[node])+'"'+'},\nposition:{x:'+str(x[node])+', y:'+str(y[node])+'},\nselected: !1\n},\n'
		# nodes+='{data:{id:"'+str(ID[node])+'", selected: !1, cytoscape_alias_list:["'+name[node]+'"], canonicalName:"'+name[node]+'", SUID:'+str(ID[node])+', NodeType:"'+codes[node][0:3]+'", CourseCode: "'+codes[node]+'", Prof: "'+prof[node]+'", Semester: "'+sem[node]+'", credits: "'+str(int(creds[node]))+'", name: "'+name[node]+'", shared_name: "'+name[node]+'"'+'},\nposition:{x:'+str(x[node])+', y:'+str(y[node])+'},\nselected: !1\n},\n'
	node+=1
	coursetocode[codes[node]] = str(ID[node])
	#nodes+='{data:{id:"'+str(ID[node])+'", selected: !1, cytoscape_alias_list:["'+name[node]+'"], canonicalName:"'+name[node]+'", SUID:'+str(ID[node])+', NodeType:"'+codes[node][0:3]+'", CourseCode: "'+codes[node]+'", Prof: "'+prof[node]+'", Semester: "'+sem[node]+'", credits: "'+str(int(creds[node]))+'", name: "'+name[node]+'", shared_name: "'+name[node]+'"'+'},\nposition:{x:'+str(x[node])+', y:'+str(y[node])+'},\nselected: !1\n}\n'+'],\n'
	nodes += '{data:{id:"'+str(ID[node])+'", selected: !1, cytoscape_alias_list:["'+str(name[node])+'"], canonicalName:"'+str(name[node])+'", SUID:'+str(ID[node])+', NodeType:"'+str(codes[node][0:3])+'", CourseCode: "'+str(codes[node])+'", Prof: "'+str(prof[node])+'", Semester: "'+str(sem[node])+'", credits: "'+str(int(creds[node]))+'", name: "'+str(name[node])+'", shared_name: "'+str(name[node])+'"'+'},\nposition:{x:'+str(x[node])+', y:'+str(y[node])+'},\nselected: !1\n}\n'+'],\n'
	edges = 'edges:[\n'
	edge_count = ID[-1]+1
	for course in range(0,len(names)):
		alt_count = 0
		for prereq in range(0, len(prerequisites[course])):
			if(prerequisites[course][prereq]!=['None']):
					if((len(prerequisites[course][prereq]) == 1) and (prerequisites[course][prereq][0] in coursetocode)):
						edge_name = coursetocode[prerequisites[course][prereq][0]]+str(course)
						edges+='{data:{id:"'+str(edge_count)+'", source:"'+coursetocode[prerequisites[course][prereq][0]]+'", target:"'+str(course+1)+'", selected: !1, canonicalName: "'+edge_name+'", SUID:'+str(edge_count)+', name: "'+edge_name+'", interaction: "cc", shared_interaction: "cc", shared_name: "'+edge_name+'"}, selected: !1'+'},\n'
						edge_count+=1
					elif((len(prerequisites[course][prereq]) != 1) and (alt_count==0)):
						alt_count+=1
						for alt in range(0, len(prerequisites[course][prereq])):
							if(prerequisites[course][prereq][alt] in coursetocode):
								edge_name = coursetocode[prerequisites[course][prereq][alt]]+str(course)
								edges+='{data:{id:"'+str(edge_count)+'", source:"'+coursetocode[prerequisites[course][prereq][alt]]+'", target:"'+str(course+1)+'", selected: !1, canonicalName: "'+edge_name+'", SUID:'+str(edge_count)+', name: "'+edge_name+'", interaction: "ORP1", shared_interaction: "ORP1", shared_name: "'+edge_name+'"}, selected: !1'+'},\n'
								edge_count+=1
					elif((len(prerequisites[course][prereq]) != 1) and (alt_count>=1)):
						alt_count+=1
						for alt in range(0, len(prerequisites[course][prereq])):
							if(prerequisites[course][prereq][alt] in coursetocode):
								edge_name = coursetocode[prerequisites[course][prereq][alt]]+str(course)
								edges+='{data:{id:"'+str(edge_count)+'", source:"'+coursetocode[prerequisites[course][prereq][alt]]+'", target:"'+str(course+1)+'", selected: !1, canonicalName: "'+edge_name+'", SUID:'+str(edge_count)+', name: "'+edge_name+'", interaction: "ORP2", shared_interaction: "ORP2", shared_name: "'+edge_name+'"}, selected: !1'+'},\n'
								edge_count+=1
	edges = edges[:-2]
	edges+='\n]\n'
	graphJS = '{\n'+nodes+edges+'}'
	with open(graphJsFilePath, "w") as jsFile:
		jsFile.write(graphJS)
		jsFile.close()


print("1 Generate Table JSON and Generate Cytoscape Graph JSON\n2 Generate TechTree Layout JSON");
n = int(input())
if(n==1):
	generate_tableJson()
	generate_graphJson()
	print("Done!")
else:
	x,y = extract_positions()
	generate_layout_graphJson(x,y)
	print("Done!")