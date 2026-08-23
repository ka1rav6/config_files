from datetime import datetime

class Assignment:
    name: str
    marks: float
    awardedMarks:float | None
    uploadedDocs : list[str]
    dateCreated:datetime
    submissionDate:datetime
    