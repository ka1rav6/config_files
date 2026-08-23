from .baseClasses import Semester
from .Assignment import Assignment
from datetime import datetime
from .Lecture import Lecture
class Course:
    credits:int
    code:str
    name:str
    dateCreated:datetime
    markDestribution: list[str] # FOR NOW
    semester:Semester
    assignments :list[Assignment]
    lectures : list[Lecture] 
    