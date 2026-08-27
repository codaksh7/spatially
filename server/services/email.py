import httpx
from config import BREVO_API_KEY, BREVO_SENDER_EMAIL, FRONTEND_URL

BREVO_API_URL = "https://api.brevo.com/v3/smtp/email"


async def send_verification_email(to_email: str, full_name: str, token: str):
    verification_link = f"{FRONTEND_URL}/verify?token={token}"

    payload = {
        "sender": {"name": "Spatially", "email": BREVO_SENDER_EMAIL},
        "to": [{"email": to_email, "name": full_name}],
        "subject": "Verify your Spatially account",
        "htmlContent": f"""
        <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 600px; margin: 0 auto; background-color: #0B0F0B; color: #E4EDE4; padding: 40px; border-radius: 12px;">
            <div style="text-align: center; margin-bottom: 32px;">
                <h1 style="color: #4A7C2E; font-size: 28px; margin: 0 0 4px 0;">Spatially</h1>
                <p style="color: #6B806B; font-size: 13px; margin: 0;">Real-time crowd intelligence for live events</p>
            </div>
            <p style="font-size: 16px; margin-bottom: 8px;">Hi {full_name},</p>
            <p style="font-size: 14px; color: #9BB09B; line-height: 1.6;">
                Thank you for creating your Spatially account. To complete your registration, please verify your email address by clicking the button below.
            </p>
            <div style="text-align: center; margin: 32px 0;">
                <a href="{verification_link}"
                   style="background-color: #4A7C2E; color: #ffffff; padding: 14px 40px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 15px; display: inline-block;">
                    Verify Email Address
                </a>
            </div>
            <p style="font-size: 13px; color: #6B806B;">
                This link will expire in 24 hours. If you did not create an account on Spatially, you can safely ignore this email.
            </p>
            <hr style="border: none; border-top: 1px solid #2A352A; margin: 28px 0;" />
            <p style="font-size: 11px; color: #4A5A4A; text-align: center;">
                Spatially &mdash; BLE-Powered Crowd Intelligence Platform
            </p>
        </div>
        """,
    }

    headers = {
        "accept": "application/json",
        "content-type": "application/json",
        "api-key": BREVO_API_KEY,
    }

    if not BREVO_API_KEY:
        print("[EMAIL] Brevo API key not configured. Skipping email send.")
        print(f"[EMAIL] Would have sent verification to {to_email}")
        print(f"[EMAIL] Verification link: {verification_link}")
        return True

    async with httpx.AsyncClient() as client:
        response = await client.post(BREVO_API_URL, json=payload, headers=headers)
        return response.status_code == 201


async def send_volunteer_invitation_email(
    to_email: str,
    organizer_name: str,
    event_name: str,
    invitation_id: str,
):
    signup_link = f"{FRONTEND_URL}/volunteer-signup?token={invitation_id}&email={to_email}"

    payload = {
        "sender": {"name": "Spatially", "email": BREVO_SENDER_EMAIL},
        "to": [{"email": to_email}],
        "subject": f"Volunteer invitation: {event_name} — Spatially",
        "htmlContent": f"""
        <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 600px; margin: 0 auto; background-color: #0B0F0B; color: #E4EDE4; padding: 40px; border-radius: 12px;">
            <div style="text-align: center; margin-bottom: 32px;">
                <h1 style="color: #4A7C2E; font-size: 28px; margin: 0 0 4px 0;">Spatially</h1>
                <p style="color: #6B806B; font-size: 13px; margin: 0;">Volunteer Invitation</p>
            </div>
            <p style="font-size: 16px; margin-bottom: 8px;">Hello,</p>
            <p style="font-size: 14px; color: #9BB09B; line-height: 1.6;">
                <strong style="color: #E4EDE4;">{organizer_name}</strong> has invited you to volunteer at
                <strong style="color: #6BA34E;">{event_name}</strong>.
            </p>
            <p style="font-size: 14px; color: #9BB09B; line-height: 1.6;">
                To accept this invitation and set up your volunteer account, click the button below:
            </p>
            <div style="text-align: center; margin: 32px 0;">
                <a href="{signup_link}"
                   style="background-color: #4A7C2E; color: #ffffff; padding: 14px 40px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 15px; display: inline-block;">
                    Accept Invitation
                </a>
            </div>
            <p style="font-size: 13px; color: #6B806B;">
                If you were not expecting this invitation, you can safely ignore this email.
            </p>
            <hr style="border: none; border-top: 1px solid #2A352A; margin: 28px 0;" />
            <p style="font-size: 11px; color: #4A5A4A; text-align: center;">
                Spatially &mdash; BLE-Powered Crowd Intelligence Platform
            </p>
        </div>
        """,
    }

    headers = {
        "accept": "application/json",
        "content-type": "application/json",
        "api-key": BREVO_API_KEY,
    }

    if not BREVO_API_KEY:
        print(f"[EMAIL] Brevo API key not configured. Skipping invitation to {to_email}")
        print(f"[EMAIL] Signup link: {signup_link}")
        return True

    async with httpx.AsyncClient() as client:
        response = await client.post(BREVO_API_URL, json=payload, headers=headers)
        return response.status_code == 201


async def send_password_reset_email(to_email: str, token: str):
    reset_link = f"{FRONTEND_URL}/reset-password?token={token}"

    payload = {
        "sender": {"name": "Spatially", "email": BREVO_SENDER_EMAIL},
        "to": [{"email": to_email}],
        "subject": "Reset your Spatially password",
        "htmlContent": f"""
        <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 600px; margin: 0 auto; background-color: #0B0F0B; color: #E4EDE4; padding: 40px; border-radius: 12px;">
            <div style="text-align: center; margin-bottom: 32px;">
                <h1 style="color: #4A7C2E; font-size: 28px; margin: 0 0 4px 0;">Spatially</h1>
            </div>
            <p style="font-size: 16px; margin-bottom: 8px;">Hello,</p>
            <p style="font-size: 14px; color: #9BB09B; line-height: 1.6;">
                We received a request to reset the password for your Spatially account. You can set a new password by clicking the button below:
            </p>
            <div style="text-align: center; margin: 32px 0;">
                <a href="{reset_link}"
                   style="background-color: #4A7C2E; color: #ffffff; padding: 14px 40px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 15px; display: inline-block;">
                    Reset Password
                </a>
            </div>
            <p style="font-size: 13px; color: #6B806B;">
                This link will expire in 1 hour. If you didn't request a password reset, you can safely ignore this email. Your password will remain unchanged.
            </p>
            <hr style="border: none; border-top: 1px solid #2A352A; margin: 28px 0;" />
            <p style="font-size: 11px; color: #4A5A4A; text-align: center;">
                Spatially &mdash; BLE-Powered Crowd Intelligence Platform
            </p>
        </div>
        """,
    }

    headers = {
        "accept": "application/json",
        "content-type": "application/json",
        "api-key": BREVO_API_KEY,
    }

    if not BREVO_API_KEY:
        print(f"[EMAIL] Brevo API key not configured. Skipping reset email to {to_email}")
        print(f"[EMAIL] Reset link: {reset_link}")
        return True

    async with httpx.AsyncClient() as client:
        response = await client.post(BREVO_API_URL, json=payload, headers=headers)
        return response.status_code == 201
