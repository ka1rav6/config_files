from backend.database import engine
from backend.models.base import Base

import backend.models.User
import backend.models.Course
import backend.models.Assignment
import backend.models.Enrollment

Base.metadata.create_all(engine)