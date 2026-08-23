from sqlalchemy import ForeignKey

from sqlalchemy.orm import Mapped
from sqlalchemy.orm import mapped_column

from .base import Base


class Enrollment(Base):
    __tablename__ = "enrollments"
    id: Mapped[int] = mapped_column( primary_key=True)
    user_id: Mapped[int] = mapped_column( ForeignKey("users.id"))
    course_id: Mapped[int] = mapped_column( ForeignKey("courses.id"))
    