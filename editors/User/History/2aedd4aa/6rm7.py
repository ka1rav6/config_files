from django.urls import path
from . import views


urlpatterns = [
    path('hello/', views.sayHello, name='say-hello'),
    path('', views.users, name = 'start-page')
]