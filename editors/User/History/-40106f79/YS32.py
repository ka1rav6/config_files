from datetime import datetime

class Lecture:
    docsUploaded : list[str]
    dateUploaded : datetime
    uploadedBy: User #teacher or TA
    