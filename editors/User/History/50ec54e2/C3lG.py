class Assignment(models.Model):
    course = models.ForeignKey(
        Course,
        on_delete=models.CASCADE
    )

    title = models.CharField(max_length=255)

    description = models.TextField()

    due_date = models.DateTimeField()

    created_at = models.DateTimeField(auto_now_add=True)