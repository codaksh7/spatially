from fastapi import APIRouter, HTTPException, Response, Request
from models import LoginRequest, SignupRequest, VolunteerSignupRequest, ProfileUpdate, UpdatePasswordRequest, ForgotPasswordRequest, ResetPasswordRequest
from config import (
    get_supabase,
    JWT_SECRET,
    JWT_ALGORITHM,
    ACCESS_TOKEN_EXPIRE_MINUTES,
    REFRESH_TOKEN_EXPIRE_DAYS,
)
from middleware.auth import get_current_user
from services.email import send_verification_email, send_password_reset_email
from jose import jwt, JWTError
from datetime import datetime, timedelta, timezone
from fastapi import Depends
import bcrypt
import uuid

router = APIRouter(prefix="/api/auth", tags=["Authentication"])


def hash_password(password: str) -> str:
    salt = bcrypt.gensalt(rounds=12)
    return bcrypt.hashpw(password.encode("utf-8"), salt).decode("utf-8")


def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode("utf-8"), hashed.encode("utf-8"))


def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(to_encode, JWT_SECRET, algorithm=JWT_ALGORITHM)


def create_refresh_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire, "type": "refresh"})
    return jwt.encode(to_encode, JWT_SECRET, algorithm=JWT_ALGORITHM)


def generate_user_id(user_type: str, supabase) -> str:
    prefix_map = {"user": "U", "volunteer": "V", "organizer": "O"}
    prefix = prefix_map[user_type]

    result = (
        supabase.table("web_users")
        .select("user_id")
        .eq("user_type", user_type)
        .execute()
    )

    max_num = 0
    for row in result.data:
        uid = row.get("user_id", "")
        try:
            num = int(uid[len(prefix):])
            if num > max_num:
                max_num = num
        except (ValueError, IndexError):
            continue

    return f"{prefix}{max_num + 1}"


def build_user_response(user: dict) -> dict:
    return {
        "user_id": user["user_id"],
        "email": user["email"],
        "user_type": user["user_type"],
        "full_name": user.get("full_name", ""),
        "nickname": user.get("nickname", ""),
        "is_verified": user.get("is_verified", False),
        "created_at": user.get("created_at", ""),
    }


@router.post("/login")
async def login(request: LoginRequest, response: Response):
    supabase = get_supabase()

    result = (
        supabase.table("web_users")
        .select("*")
        .eq("email", request.email)
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=401, detail="Invalid email or password")

    user = result.data[0]

    if not verify_password(request.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    if not user.get("is_verified", False):
        raise HTTPException(
            status_code=403,
            detail="Please verify your email before logging in. Check your inbox for the verification link.",
        )

    token_data = {
        "user_id": user["user_id"],
        "email": user["email"],
        "user_type": user["user_type"],
    }

    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)

    response.set_cookie(
        key="refresh_token",
        value=refresh_token,
        httponly=True,
        secure=True,
        samesite="none",
        max_age=REFRESH_TOKEN_EXPIRE_DAYS * 86400,
        path="/",
    )

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": build_user_response(user),
    }


@router.post("/signup")
async def signup(request: SignupRequest):
    supabase = get_supabase()

    existing = (
        supabase.table("web_users")
        .select("email")
        .eq("email", request.email)
        .execute()
    )
    if existing.data:
        raise HTTPException(
            status_code=409, detail="An account with this email already exists"
        )

    user_id = generate_user_id("user", supabase)
    verification_token = str(uuid.uuid4())
    password_hash = hash_password(request.password)

    new_user = {
        "user_id": user_id,
        "email": request.email,
        "password_hash": password_hash,
        "user_type": "user",
        "full_name": request.full_name,
        "nickname": request.nickname or "",
        "is_verified": False,
        "verification_token": verification_token,
        "verification_token_expires": (
            datetime.now(timezone.utc) + timedelta(hours=24)
        ).isoformat(),
    }

    supabase.table("web_users").insert(new_user).execute()

    await send_verification_email(request.email, request.full_name, verification_token)

    return {
        "message": "Account created successfully. Please check your email to verify your account.",
        "user_id": user_id,
    }


@router.post("/volunteer-signup")
async def volunteer_signup(request: VolunteerSignupRequest):
    supabase = get_supabase()

    invitation = (
        supabase.table("event_invitations")
        .select("*")
        .eq("id", request.invitation_token)
        .eq("volunteer_email", request.email)
        .eq("status", "pending")
        .execute()
    )

    if not invitation.data:
        raise HTTPException(status_code=400, detail="Invalid or expired invitation")

    existing = (
        supabase.table("web_users")
        .select("email")
        .eq("email", request.email)
        .execute()
    )
    if existing.data:
        raise HTTPException(
            status_code=409, detail="An account with this email already exists"
        )

    user_id = generate_user_id("volunteer", supabase)
    password_hash = hash_password(request.password)

    new_user = {
        "user_id": user_id,
        "email": request.email,
        "password_hash": password_hash,
        "user_type": "volunteer",
        "full_name": request.full_name,
        "nickname": request.nickname or "",
        "is_verified": True,
        "verification_token": None,
    }

    supabase.table("web_users").insert(new_user).execute()

    inv = invitation.data[0]
    supabase.table("event_invitations").update(
        {"status": "accepted", "volunteer_user_id": user_id}
    ).eq("id", inv["id"]).execute()

    supabase.table("web_volunteer_assignments").insert(
        {"volunteer_user_id": user_id, "event_id": inv["event_id"]}
    ).execute()

    return {
        "message": "Volunteer account created and event assignment confirmed.",
        "user_id": user_id,
    }


@router.get("/verify")
async def verify_email(token: str):
    supabase = get_supabase()

    result = (
        supabase.table("web_users")
        .select("*")
        .eq("verification_token", token)
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=400, detail="Invalid verification token")

    user = result.data[0]

    if user.get("is_verified"):
        return {"message": "Email already verified"}

    expires = user.get("verification_token_expires")
    if expires:
        try:
            exp_str = expires.replace("Z", "+00:00") if expires.endswith("Z") else expires
            exp_dt = datetime.fromisoformat(exp_str)
            if not exp_dt.tzinfo:
                exp_dt = exp_dt.replace(tzinfo=timezone.utc)
            if datetime.now(timezone.utc) > exp_dt:
                raise HTTPException(
                    status_code=400, detail="Verification token has expired"
                )
        except (ValueError, TypeError):
            pass

    supabase.table("web_users").update(
        {
            "is_verified": True,
            "verification_token": None,
            "verification_token_expires": None,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
    ).eq("user_id", user["user_id"]).execute()

    return {"message": "Email verified successfully. You can now log in."}


@router.post("/refresh")
async def refresh_token(request: Request, response: Response):
    refresh = request.cookies.get("refresh_token")
    if not refresh:
        raise HTTPException(status_code=401, detail="No refresh token provided")

    try:
        payload = jwt.decode(refresh, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

    if payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid token type")

    supabase = get_supabase()
    result = (
        supabase.table("web_users")
        .select("*")
        .eq("user_id", payload["user_id"])
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=401, detail="Account not found")

    user = result.data[0]
    token_data = {
        "user_id": user["user_id"],
        "email": user["email"],
        "user_type": user["user_type"],
    }

    new_access = create_access_token(token_data)
    new_refresh = create_refresh_token(token_data)

    response.set_cookie(
        key="refresh_token",
        value=new_refresh,
        httponly=True,
        secure=True,
        samesite="none",
        max_age=REFRESH_TOKEN_EXPIRE_DAYS * 86400,
        path="/",
    )

    return {
        "access_token": new_access,
        "token_type": "bearer",
        "user": build_user_response(user),
    }


@router.post("/logout")
async def logout(response: Response):
    response.delete_cookie("refresh_token", path="/")
    return {"message": "Logged out successfully"}


@router.get("/me")
async def get_me(current_user: dict = Depends(get_current_user)):
    return {"user": build_user_response(current_user)}


@router.put("/profile")
async def update_profile(
    data: ProfileUpdate, current_user: dict = Depends(get_current_user)
):
    supabase = get_supabase()
    updates = {"updated_at": datetime.now(timezone.utc).isoformat()}

    if data.full_name is not None:
        updates["full_name"] = data.full_name.strip()
    if data.nickname is not None:
        updates["nickname"] = data.nickname.strip()

    supabase.table("web_users").update(updates).eq(
        "user_id", current_user["user_id"]
    ).execute()

    updated = (
        supabase.table("web_users")
        .select("*")
        .eq("user_id", current_user["user_id"])
        .execute()
    )

    return {"user": build_user_response(updated.data[0])}


@router.post("/update-password")
async def update_password(
    data: UpdatePasswordRequest, current_user: dict = Depends(get_current_user)
):
    supabase = get_supabase()

    result = (
        supabase.table("web_users")
        .select("*")
        .eq("user_id", current_user["user_id"])
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Account not found")

    user = result.data[0]

    if not verify_password(data.current_password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Incorrect current password")

    new_hash = hash_password(data.new_password)

    supabase.table("web_users").update(
        {
            "password_hash": new_hash,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
    ).eq("user_id", current_user["user_id"]).execute()

    return {"message": "Password updated successfully"}


@router.post("/forgot-password")
async def forgot_password(request: ForgotPasswordRequest):
    supabase = get_supabase()

    result = (
        supabase.table("web_users")
        .select("*")
        .eq("email", request.email)
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=404, 
            detail="If this email is registered, a password reset link has been sent."
        )

    user = result.data[0]
    reset_token = str(uuid.uuid4())
    expires = (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()

    supabase.table("web_users").update(
        {
            "reset_token": reset_token,
            "reset_token_expires": expires,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
    ).eq("user_id", user["user_id"]).execute()

    await send_password_reset_email(request.email, reset_token)

    return {"message": "If this email is registered, a password reset link has been sent."}


@router.post("/reset-password")
async def reset_password(request: ResetPasswordRequest):
    if request.new_password != request.confirm_password:
        raise HTTPException(status_code=400, detail="Passwords do not match")

    supabase = get_supabase()

    result = (
        supabase.table("web_users")
        .select("*")
        .eq("reset_token", request.token)
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=400, detail="Invalid or expired reset token")

    user = result.data[0]
    
    expires = user.get("reset_token_expires")
    if expires:
        try:
            exp_str = expires.replace("Z", "+00:00") if expires.endswith("Z") else expires
            exp_dt = datetime.fromisoformat(exp_str)
            if not exp_dt.tzinfo:
                exp_dt = exp_dt.replace(tzinfo=timezone.utc)
            if datetime.now(timezone.utc) > exp_dt:
                raise HTTPException(status_code=400, detail="Reset token has expired")
        except (ValueError, TypeError):
            raise HTTPException(status_code=400, detail="Invalid token expiry")

    new_hash = hash_password(request.new_password)

    supabase.table("web_users").update(
        {
            "password_hash": new_hash,
            "reset_token": None,
            "reset_token_expires": None,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
    ).eq("user_id", user["user_id"]).execute()

    return {"message": "Your password has been successfully reset. You can now log in."}
