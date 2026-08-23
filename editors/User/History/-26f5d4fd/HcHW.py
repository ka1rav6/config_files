from django.db import models

class Submission(models.Model):

    assignment = models.ForeignKey(
        Assignment,
        on_delete=models.CASCADE
    )

    student = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE
    )

    file = models.FileField(
        upload_to="submissions/"
    )

    submitted_at = models.DateTimeField(
        auto_now_add=True
    )

    grade = models.FloatField(
        null=True,
        blank=True
    )

    feedback = models.TextField(
        blank=True
    )