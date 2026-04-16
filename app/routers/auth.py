from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select, func

from app.auth import hash_password, verify_password, create_access_token, get_current_user, require_admin
from app.database import get_session
from app.models import User
from app.schemas import (
    RegisterRequest, LoginRequest, TokenResponse, UserResponse,
    UpdatePermissionRequest, MessageResponse,
)

router = APIRouter()


def _token_response(user: User) -> TokenResponse:
    token = create_access_token(user.id, user.name)
    return TokenResponse(
        access_token=token,
        user_id=user.id,
        name=user.name,
        nickname=user.nickname,
        role=user.role,
        can_upload=user.can_upload,
        can_delete=user.can_delete,
        can_download=user.can_download,
    )


def _user_response(user: User) -> UserResponse:
    return UserResponse(
        id=user.id,
        name=user.name,
        nickname=user.nickname,
        role=user.role,
        can_upload=user.can_upload,
        can_delete=user.can_delete,
        can_download=user.can_download,
        created_at=user.created_at,
    )


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(req: RegisterRequest, session: Session = Depends(get_session)):
    """Register a new user. First user becomes admin."""
    name = req.name.strip()
    nickname = req.nickname.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Name is required")
    if not nickname:
        raise HTTPException(status_code=400, detail="Nickname is required")
    if len(req.password) < 4:
        raise HTTPException(status_code=400, detail="Password must be at least 4 characters")

    existing = session.exec(select(User).where(User.name == name)).first()
    if existing:
        raise HTTPException(status_code=409, detail="Name already taken")

    # First user becomes admin
    user_count = session.exec(select(func.count()).select_from(User)).one()
    role = "admin" if user_count == 0 else "member"

    user = User(name=name, nickname=nickname, password_hash=hash_password(req.password), role=role)
    session.add(user)
    session.commit()
    session.refresh(user)

    return _token_response(user)


@router.post("/login", response_model=TokenResponse)
async def login(req: LoginRequest, session: Session = Depends(get_session)):
    """Login with name and password."""
    user = session.exec(select(User).where(User.name == req.name.strip())).first()
    if not user or not verify_password(req.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid name or password")

    return _token_response(user)


@router.get("/me", response_model=UserResponse)
async def get_me(user: User = Depends(get_current_user)):
    """Get current authenticated user info."""
    return _user_response(user)


@router.get("/users", response_model=list[UserResponse])
async def list_users(
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """List all registered users."""
    users = session.exec(select(User).order_by(User.created_at)).all()
    return [_user_response(u) for u in users]


@router.put("/users/{user_id}/permissions", response_model=UserResponse)
async def update_permissions(
    user_id: str,
    req: UpdatePermissionRequest,
    admin: User = Depends(require_admin),
    session: Session = Depends(get_session),
):
    """Admin: update a user's permissions."""
    target = session.get(User, user_id)
    if not target:
        raise HTTPException(status_code=404, detail="User not found")

    if target.role == "admin":
        raise HTTPException(status_code=400, detail="Cannot change admin permissions")

    if req.can_upload is not None:
        target.can_upload = req.can_upload
    if req.can_delete is not None:
        target.can_delete = req.can_delete
    if req.can_download is not None:
        target.can_download = req.can_download

    session.add(target)
    session.commit()
    session.refresh(target)

    return _user_response(target)
