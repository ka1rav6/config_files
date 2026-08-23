from sqlalchemy import String, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from .base import Base, TimeStamp


class Lecture(TimeStamp, Base):
    __tablename__                   = "lectures"
    id: Mapped[int]                 = mapped_column(primary_key=True)
    title: Mapped[str]              = mapped_column(String(100))
    description: Mapped[str | None] = mapped_column(String(500))
    course_id: Mapped[int]          = mapped_column(ForeignKey("courses.id"))
    uploaded_by: Mapped[int]        = mapped_column(ForeignKey("users.id"))
    file_path: Mapped[str]          = mapped_column(String(500))
    course   = relationship("Course")
    uploader = relationship("User")
    files    = relationship(
        "LectureFile", back_populates="lecture", cascade="all, delete-orphan"
    )
    def __repr__(self) -> str:
        return f"<Lecture(id={self.id}, title={self.title})>"


class LectureFile(Base):
    __tablename__ = "lecture_files"

    id: Mapped[int] = mapped_column(primary_key=True)
    lecture_id: Mapped[int] = mapped_column(ForeignKey("lectures.id"))
    file_name: Mapped[str] = mapped_column(String(255))
    file_path: Mapped[str] = mapped_column(String(500))
    lecture = relationship("Lecture", back_populates="files")

    def __repr__(self) -> str:
        return f"<LectureFile(id={self.id}, file_name={self.file_name})>"