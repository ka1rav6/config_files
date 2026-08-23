from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, TimeStamp


class Enrollment(TimeStamp, Base):
    __tablename__ = "enrollments"

    id: Mapped[int]        = mapped_column(primary_key=True)
    user_id: Mapped[int]   = mapped_column(ForeignKey("users.id"))
    course_id: Mapped[int] = mapped_column(ForeignKey("courses.id"))
    user = relationship("User")
    course = relationship("Course")

    def __repr__(self) -> str:
        return f"<Enrollment(id={self.id}, user_id={self.user_id}, course_id={self.course_id})>"