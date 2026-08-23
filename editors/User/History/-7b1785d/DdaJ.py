from baseUser import Role, BaseUser
from pydantic import EmailStr, validate_email
from datetime import datetime

class Teacher(BaseUser):
    def __init__(self, username:str, password:str|None = None, email:EmailStr|None = None, role:Role = Role.STUDENT) -> None:
        super().__init__(username, password, email, Role.TEACHER)

    def createAssignment(uploadedDoc : None | str | list[str], submissionTime :datetime, marks: float, instructionText: str | None = None, uploadedDate:datetime = datetime.now())-> None:
        pass
    def uploadLecture(uploadedDoc:list[str] | str | None, instructionText :str | None = None, uploadedDate: datetime = datetime.now()) -> None:
        pass