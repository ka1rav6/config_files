from enum import Enum, auto

class Roles(Enum):
    ADMIN = auto()
    TEACHER = auto()
    TA = auto()
    STUDENT = auto()
    
class BaseUser:
    
    def __init__(self, ) -> None:
        pass