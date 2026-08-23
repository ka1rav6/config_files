# models/Submission.py

from datetime import datetime

from sqlalchemy import String, Float, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, TimeStamp


class Submission(TimeStamp, Base):
    __tablename__                  = "submissions"
    id: Mapped[int]                = mapped_column(primary_key=True)
    assignment_id: Mapped[int]     = mapped_column(ForeignKey("assignments.id"))
    student_id: Mapped[int]        = mapped_column(ForeignKey("users.id"))
    submitted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    grade: Mapped[float | None]    = mapped_column(Float, nullable=True)
    feedback: Mapped[str | None]   = mapped_column(String(1000), nullable=True)
    
    files = relationship(
        "SubmissionFile", back_populates="submission", cascade="all, delete-orphan"
    )
    def __repr__(self) -> str:
        return f"<Submission(id={self.id}, assignment_id={self.assignment_id}, student_id={self.student_id})>"


class SubmissionFile(Base):
    __tablename__              = "submission_files"
    id: Mapped[int]            = mapped_column(primary_key=True)
    submission_id: Mapped[int] = mapped_column(ForeignKey("submissions.id"))
    file_name: Mapped[str]     = mapped_column(String(255))
    file_path: Mapped[str]     = mapped_column(String(500))
    
    submission = relationship("Submission", back_populates="files")
    def __repr__(self) -> str:
        return f"<SubmissionFile(id={self.id}, file_name={self.file_name})>"