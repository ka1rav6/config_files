from django.contrib import admin
from .models import Submission, TutorialSubmission, SubmissionFile, TutorialSubmissionFile

@admin.register(Submission)
class SubmissionAdmin(admin.ModelAdmin):
    list_display = ["student", "assignment", "submitted_at", "grade"]
    search_fields = ["student__username", "assignment__title"]
    list_filter = ["assignment", "submitted_at"]

@admin.register(TutorialSubmission)
class TutorialSubmissionAdmin(admin.ModelAdmin):username
    list_display = ["student", "tutorial", "submitted_at", "grade"]
    search_fields = ["student__username", "tutorial__title"]
    list_filter = ["tutorial", "submitted_at"]

@admin.register(SubmissionFile)
class SubmissionFileAdmin(admin.ModelAdmin):
    list_display = ["file_name", "submission", "uploaded_at"]
    search_fields = ["file_name", "submission__student__username"]
    list_filter = ["submission", "uploaded_at"]

@admin.register(TutorialSubmissionFile)
class TutorialSubmissionFileAdmin(admin.ModelAdmin):
    list_display = ["file_name", "submission", "uploaded_at"]
    search_fields = ["file_name", "submission__student__username"]
    list_filter = ["submission", "uploaded_at"]
