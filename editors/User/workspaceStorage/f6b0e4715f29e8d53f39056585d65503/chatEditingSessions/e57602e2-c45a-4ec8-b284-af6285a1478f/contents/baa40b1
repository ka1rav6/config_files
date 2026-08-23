"""Comment service — creation, listing, editing, deleting and reporting.

Ownership is enforced here (never in the router or the client): only the
comment's author — or an admin — may edit or delete it. Comments can only be
left on posts the requester is allowed to read (published ones for everyone).
"""
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import AppError
from app.models.comment import Comment, CommentStatus
from app.config import settings
from app.models.user import User, UserRole
from app.repositories.comments import CommentRepository
from app.schemas.comment import CommentCreate, CommentUpdate
from app.services.posts import PostService
from app.services.rate_limit import rate_limiter
from app.config import settings

# Longest comment body we accept (matches the schema constraint).
MAX_COMMENT_LENGTH = 2000


class CommentService:
    """Encapsulates the rules around comments."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = CommentRepository(session)

    # --- helpers ---------------------------------------------------------

    async def _get_comment(self, public_id: UUID) -> Comment:
        """Fetch a comment or raise the standard 404 envelope."""
        comment = await self._repo.get_by_public_id(public_id)
        if comment is None:
            raise AppError(404, "not_found", "Comment not found")
        return comment

    def _assert_can_modify(self, comment: Comment, user: User) -> None:
        """Admins may touch anything; everyone else only their own comments."""
        if user.role == UserRole.ADMIN or comment.author_id == user.id:
            return
        raise AppError(403, "forbidden", "You can only modify your own comments")

    def _clean_content(self, content: str) -> str:
        """Trim whitespace and enforce the length cap."""
        cleaned = content.strip()
        if not cleaned:
            raise AppError(422, "validation_error", "Comment cannot be empty")
        if len(cleaned) > MAX_COMMENT_LENGTH:
            raise AppError(
                422,
                "validation_error",
                f"Comment cannot be longer than {MAX_COMMENT_LENGTH} characters",
            )
        return cleaned

    # --- public operations ------------------------------------------------

    async def list_for_post(self, post_id: UUID, user: User | None) -> list[Comment]:
        """List a post's visible comments (admins additionally see the rest).

        Reuses PostService.get_for_reader so strangers cannot enumerate
        comments on private drafts — the post itself 404s first.
        """
        post = await PostService(self._session).get_for_reader(post_id, user)
        include_non_visible = user is not None and user.role == UserRole.ADMIN
        return await self._repo.list_for_post(post.id, include_non_visible=include_non_visible)

    async def create(self, post_id: UUID, payload: CommentCreate, user: User) -> Comment:
        """Leave a comment on a post the user is allowed to read."""
        # 404s for drafts the user cannot see, exactly like the post endpoint.
        post = await PostService(self._session).get_for_reader(post_id, user)

        # Enforce per-user comment creation rate limit.
        rate_limiter.check(
            f"comments:{user.id}",
            settings.comment_rate_limit_attempts,
            settings.comment_rate_limit_window_seconds,
        )

        comment = Comment(
            post_id=post.id,
            author_id=user.id,
            content=self._clean_content(payload.content),
            status=CommentStatus.VISIBLE,
        )
        self._session.add(comment)
        await self._session.commit()
        # Re-read so the response includes the eager-loaded author relation.
        return await self._get_comment(comment.public_id)

    async def update(self, public_id: UUID, payload: CommentUpdate, user: User) -> Comment:
        """Edit a comment's body (author or admin only)."""
        comment = await self._get_comment(public_id)
        self._assert_can_modify(comment, user)
        comment.content = self._clean_content(payload.content)
        await self._session.commit()
        return await self._get_comment(public_id)

    async def delete(self, public_id: UUID, user: User) -> None:
        """Delete a comment (author or admin only)."""
        comment = await self._get_comment(public_id)
        self._assert_can_modify(comment, user)
        await self._session.delete(comment)
        await self._session.commit()

    async def report(self, public_id: UUID, user: User) -> Comment:
        """Flag a comment for moderation; track reports and hide after threshold.

        Any signed-in reader can report once; reporting increments a counter. When
        the count reaches COMMENT_REPORT_THRESHOLD, the comment is auto-hidden
        from the public list. This prevents any single user from silently
        censoring a comment on their own, while still giving admins the ability
        to manually review/reported comments.
        """
        comment = await self._get_comment(public_id)

        if comment.author_id == user.id:
            raise AppError(422, "validation_error", "You cannot report your own comment")

        # Invalidate any previous report by this user (idempotent reporting).
        if not getattr(comment, "user_reported", False):
            comment.report_count += 1
            comment.user_reported = True

            await self._session.commit()

            # If threshold reached, hide from public lists (admins can still see).
            if comment.report_count >= settings.comment_report_threshold:
                comment.status = CommentStatus.REPORTED

                await self._session.commit()

        return await self._get_comment(public_id)
