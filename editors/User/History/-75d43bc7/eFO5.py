
from fastapi import APIRouter

router = APIRouter(prefix="/users", tags=["Users"])

@router.post("/register")
def register():
    return {"message": "Register User"}

@router.post("/login")
def login():
    return {"message": "Login user"}