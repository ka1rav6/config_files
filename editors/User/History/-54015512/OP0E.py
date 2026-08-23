from .baseClasses import Semester
from .Assignment import Assignment
from .Lecture import Lecture
class Course:
    credits:int
    code:str
    name:str
    markDestribution: list[str] # FOR NOW
    semester:Semester
    assignments :list[Assignment]
    lectures : list[lectures] 