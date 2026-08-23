"""Report model — readers flag inappropriate comments for moderation."""
from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import BigInteger, ForeignKey, PrimaryKeyConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.comment import Comment
    from app.models.user import User


class CommentReport(TimestampMixin, Base):
    """A unique report of a comment by one reader."""

    __tablename__ = "comment_reports"
    __table_args__ = (PrimaryKeyConstraint("comment_id", "reporter_id"),)

    comment_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("comments.id", ondelete="CASCADE"), primary_key=True
    )
    reporter_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )

    comment: Mapped["Comment"] = relationship("Comment", back_populates="reports")  # noqa: UP037
    reporter: Mapped["User"] = relationship("User")  # noqa: UP037
