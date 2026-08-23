# Assignment.py

from datetime import datetime

from sqlalchemy import String
from sqlalchemy import Float
from sqlalchemy import DateTime
from sqlalchemy import ForeignKey

from sqlalchemy.orm import Mapped
from sqlalchemy.orm import mapped_column
from sqlalchemy.orm import relationship

from .base import Base


class Assignment(Base):
    __tablename__ = "assignments"

    # id: Mapped[int] = mapped_column( primary_key=True)

    # name: Mapped[str] = mapped_column( String(100))

    # instructions: Mapped[str | None] = mapped_column( String(500),nullable=True
    )

    # marks: Mapped[float] = mapped_column( Float)

    # created_at: Mapped[datetime] = mapped_column( DateTime,default=datetime.utcnow
    )

    # submission_deadline: Mapped[datetime] = mapped_column( DateTime)

    # course_id: Mapped[int] = mapped_column( ForeignKey("courses.id"))

    # course = relationship( "Course")