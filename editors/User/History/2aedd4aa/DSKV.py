from django.urls import path
from . import views


urlpatterns = [
    path('src/apps/users/views.py', views.sayHello)
]