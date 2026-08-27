import { useEffect, useState } from "react";
import { useSearchParams, Link } from "react-router-dom";
import { api } from "../utils/api";
import { LuCircleCheck, LuCircleX, LuLoader } from "react-icons/lu";

export default function VerifyEmail() {
  const [searchParams] = useSearchParams();
  const token = searchParams.get("token");
  const [status, setStatus] = useState("verifying");
  const [message, setMessage] = useState("");

  useEffect(() => {
    if (!token) {
      setStatus("error");
      setMessage("No verification token provided");
      return;
    }

    api
      .get(`/api/auth/verify?token=${token}`, { skipRefresh: true })
      .then((data) => {
        setStatus("success");
        setMessage(data.message || "Email verified successfully");
      })
      .catch((err) => {
        setStatus("error");
        setMessage(err.message || "Verification failed");
      });
  }, [token]);

  return (
    <div className="auth-page">
      <div className="auth-container" style={{ textAlign: "center" }}>
        {status === "verifying" && (
          <>
            <div className="spinner spinner-lg" style={{ margin: "0 auto 20px" }}></div>
            <h2>Verifying your email...</h2>
            <p style={{ color: "var(--text-muted)", marginTop: "8px" }}>Please wait a moment</p>
          </>
        )}

        {status === "success" && (
          <>
            <LuCircleCheck size={56} color="var(--green-400)" style={{ marginBottom: "20px" }} />
            <h2 style={{ marginBottom: "8px" }}>Email Verified</h2>
            <p style={{ color: "var(--text-secondary)", marginBottom: "24px" }}>{message}</p>
            <Link to="/login" className="btn btn-primary btn-lg">
              Continue to Login
            </Link>
          </>
        )}

        {status === "error" && (
          <>
            <LuCircleX size={56} color="var(--error)" style={{ marginBottom: "20px" }} />
            <h2 style={{ marginBottom: "8px" }}>Verification Failed</h2>
            <p style={{ color: "var(--text-secondary)", marginBottom: "24px" }}>{message}</p>
            <Link to="/login" className="btn btn-secondary btn-lg">
              Go to Login
            </Link>
          </>
        )}
      </div>
    </div>
  );
}
