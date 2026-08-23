from database import engine

from models.base import Base

# Import all models so SQLAlchemy registers them
from models.User import User
from models.Course import Course
from models.Assignment import Assignment
from models.Enrollment import Enrollment
from models.Lecture import Lecture

Base.metadata.create_all(bind=engine)

print("Tables created successfully.")