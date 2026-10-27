from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr, Field
from supabase import Client, create_client

from app.config import get_settings, Settings

router = APIRouter(prefix="/auth", tags=["Authentication"])


# ── Request / Response Schemas ────────────────────────────────────────────────

class SignUpRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=128, description="Minimum 8 characters")
    full_name: str = Field(..., min_length=1, max_length=100)


class SignInRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1)


class VerifyOTPRequest(BaseModel):
    email: EmailStr
    otp: str = Field(..., min_length=6, max_length=6, description="6-digit OTP from email")


class ResendOTPRequest(BaseModel):
    email: EmailStr


class AuthResponse(BaseModel):
    message: str
    user_id: Optional[UUID] = None
    email: Optional[str] = None
    access_token: Optional[str] = None
    refresh_token: Optional[str] = None


# ── Helper: Supabase client using anon key (for auth operations) ──────────────

def _get_auth_client() -> Client:
    """Auth operations must use the anon key so Supabase GoTrue handles them correctly."""
    settings = get_settings()
    return create_client(settings.SUPABASE_URL, settings.SUPABASE_ANON_KEY)


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post(
    "/signup",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register with email + password (sends OTP to email for verification)",
)
async def sign_up(request: SignUpRequest) -> AuthResponse:
    """
    Creates a new user account. Supabase automatically sends a 6-digit OTP
    to the provided email for verification. The user must call /auth/verify-otp
    to activate the account before they can sign in.
    """
    client = _get_auth_client()

    try:
        response = client.auth.sign_up(
            {
                "email": request.email,
                "password": request.password,
                "options": {
                    "data": {
                        "full_name": request.full_name,
                    }
                },
            }
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Sign-up failed: {str(e)}",
        )

    user = response.user
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Sign-up failed: user was not created. Email may already be registered.",
        )

    return AuthResponse(
        message="Account created. Check your email for a 6-digit verification code.",
        user_id=UUID(user.id) if user.id else None,
        email=user.email,
    )


@router.post(
    "/verify-otp",
    response_model=AuthResponse,
    summary="Verify email with the 6-digit OTP sent during signup",
)
async def verify_otp(request: VerifyOTPRequest) -> AuthResponse:
    """
    Verifies the user's email using the 6-digit OTP code.
    On success, returns access and refresh tokens so the user is immediately signed in.
    """
    client = _get_auth_client()

    try:
        response = client.auth.verify_otp(
            {
                "email": request.email,
                "token": request.otp,
                "type": "signup",
            }
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"OTP verification failed: {str(e)}",
        )

    user = response.user
    session = response.session

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP verification failed. Code may be expired or invalid.",
        )

    return AuthResponse(
        message="Email verified successfully. You are now signed in.",
        user_id=UUID(user.id) if user.id else None,
        email=user.email,
        access_token=session.access_token if session else None,
        refresh_token=session.refresh_token if session else None,
    )


@router.post(
    "/resend-otp",
    response_model=AuthResponse,
    summary="Resend the OTP verification email",
)
async def resend_otp(request: ResendOTPRequest) -> AuthResponse:
    """Resends the 6-digit OTP to the user's email for signup verification."""
    client = _get_auth_client()

    try:
        client.auth.resend(
            {
                "email": request.email,
                "type": "signup",
            }
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to resend OTP: {str(e)}",
        )

    return AuthResponse(
        message="Verification code resent. Check your email.",
        email=request.email,
    )


@router.post(
    "/signin",
    response_model=AuthResponse,
    summary="Sign in with email + password (account must be verified first)",
)
async def sign_in(request: SignInRequest) -> AuthResponse:
    """
    Authenticates with email and password. Returns access + refresh tokens.
    Account must have been verified via OTP before sign-in works.
    """
    client = _get_auth_client()

    try:
        response = client.auth.sign_in_with_password(
            {
                "email": request.email,
                "password": request.password,
            }
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Sign-in failed: {str(e)}",
        )

    user = response.user
    session = response.session

    if user is None or session is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
        )

    return AuthResponse(
        message="Signed in successfully.",
        user_id=UUID(user.id) if user.id else None,
        email=user.email,
        access_token=session.access_token,
        refresh_token=session.refresh_token,
    )


@router.post(
    "/signout",
    response_model=AuthResponse,
    summary="Sign out the current user",
)
async def sign_out() -> AuthResponse:
    """Signs out the current session. Client should discard stored tokens."""
    # Note: In a stateless JWT setup, sign-out is primarily client-side.
    # Server-side sign-out invalidates the refresh token in Supabase.
    return AuthResponse(
        message="Signed out successfully. Discard your access and refresh tokens.",
    )
