from pydantic import BaseModel, ConfigDict, EmailStr

class UserCreate(BaseModel):
    username: str
    email: EmailStr
    password: str
    firstName: str
    lastName: str
    role: str

class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    firstName: str
    lastName: str
    role: str
    model_config = ConfigDict(from_attributes=True)