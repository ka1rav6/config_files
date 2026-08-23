from baseUser import Role, BaseUser
from pydantic import EmailStr, validate_email

class Teacher(BaseUser):
    