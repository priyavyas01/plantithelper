import resend
import os
from dotenv import load_dotenv

load_dotenv()

resend.api_key = os.getenv("RESEND_API_KEY")
FROM_EMAIL = os.getenv("RESEND_FROM_EMAIL", "PlantIt Helper <onboarding@resend.dev>")


def send_password_reset_email(to_email: str, code: str) -> None:
    resend.Emails.send({
        "from": FROM_EMAIL,
        "to": to_email,
        "subject": "Password Reset - PlantIt Helper",
        "html": f"""
        <div style="font-family: sans-serif; max-width: 480px; margin: 0 auto; padding: 32px;">
            <h2 style="color: #4CAF50;">Password Reset</h2>
            <p>Hi,</p>
            <p>We got a request to reset your PlantIt Helper password.</p>
            <div style="
                background: #f5f5f5;
                border-radius: 8px;
                padding: 24px;
                text-align: center;
                margin: 24px 0;
            ">
                <p style="margin: 0 0 8px 0; color: #666; font-size: 13px;">Your reset code</p>
                <span style="font-size: 36px; font-weight: bold; letter-spacing: 8px; color: #333;">
                    {code}
                </span>
                <p style="margin: 8px 0 0 0; color: #888; font-size: 12px;">Expires in 15 minutes</p>
            </div>
            <p style="color: #888; font-size: 13px;">
                If you didn't request this, you can safely ignore this email.
                Your password won't change.
            </p>
        </div>
        """,
    })
