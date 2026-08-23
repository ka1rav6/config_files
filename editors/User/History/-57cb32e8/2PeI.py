from enum import Enum, auto

class Roles(Enum):
    ADMIN = auto()
    TEACHER = auto()
    TA = auto()
    STUDENT = auto()
    
class BaseUser:
    username:str
    __password:str
    
    def __init__(self, ) -> None:
        pass