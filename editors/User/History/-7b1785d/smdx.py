from backend.models.baseClasses import Role, BaseUser, Semester
from pydantic import EmailStr
from datetime import datetime
from .Course import Course

class Teacher(BaseUser):
    coursesTaught:list[Course]
    def __init__(self, username:str, password:str|None = None, email:EmailStr|None = None, role:Role = Role.STUDENT) -> None:
        super().__init__(username, password, email, Role.TEACHER)

    def createAssignment(self, uploadedDoc : None | str | list[str], assignmentName:str, submissionTime :datetime, marks: float, instructionText: str | None = None, uploadedDate:datetime = datetime.now())-> None:
        pass
    def uploadLecture(self, uploadedDoc:list[str] | str | None, lectureName:str, instructionText :str | None = None, uploadedDate: datetime = datetime.now()) -> None:
        pass
    def createCourse(self, courseName:str, courseCredits:int, semester:Semester)->None:
        pass
    def createAnnouncement(self, announcementName:str, announcementBody: str, announcementTime:datetime = datetime.now()):
        pass
    def addToCourse(course:Course):
        ## ADD STUDENTS AND TAS TO THE COURSE
        pass