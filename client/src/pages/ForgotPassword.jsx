import { useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../utils/api";
import { useToast } from "../components/Toast";
import { validateEmail } from "../utils/validators";
import { LuLoader, LuArrowLeft, LuCheck } from "react-icons/lu";

export default function ForgotPassword() {
  const [email, setEmail] = useState("");
  const [errors, setErrors] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);
  const toast = useToast();

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    const emailErr = validateEmail(email);
    if (emailErr) {
      setErrors({ email: emailErr });
      return;
    }
    
    setErrors({});
    setSubmitting(true);
    
    try {
      await api.post("/api/auth/forgot-password", { email });
      setSuccess(true);
      toast("Password reset link sent", "success");
    } catch (err) {
      if (err.status === 404) {
        setErrors({ form: err.message || "Email address not found. Please check and try again." });
      } else {
        setErrors({ form: err.message || "Failed to process request. Please try again later." });
      }
    } finally {
      setSubmitting(false);
    }
  };

  if (success) {
    return (
      <div className="auth-page">
        <div className="auth-container">
          <div className="auth-logo">
            <h1>Spatial<span style={{ color: "var(--text-primary)" }}>Ly</span></h1>
          </div>
          <div className="auth-card" style={{ textAlign: "center" }}>
            <LuCheck size={48} style={{ color: "var(--green-400)", margin: "0 auto 16px" }} />
            <h2 style={{ marginBottom: "12px" }}>Check your email</h2>
            <p className="auth-subtitle" style={{ marginBottom: "24px", lineHeight: "1.6" }}>
              If an account exists for <strong>{email}</strong>, we have sent a password reset link. 
              Please check your inbox and spam folder.
            </p>
            <Link to="/login" className="btn btn-secondary w-full">Return to Login</Link>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="auth-page">
      <div className="auth-container">
        <div className="auth-logo">
          <h1>Spatial<span style={{ color: "var(--text-primary)" }}>Ly</span></h1>
          <p>Real-time crowd intelligence</p>
        </div>

        <div className="auth-card">
          <h2>Reset Password</h2>
          <p className="auth-subtitle">Enter your email address and we'll send you a link to reset your password.</p>

          <form onSubmit={handleSubmit} noValidate>
            <div className="form-group">
              <label className="form-label" htmlFor="reset-email">Email Address</label>
              <input
                id="reset-email"
                type="email"
                className={`form-input ${errors.email ? "error" : ""}`}
                placeholder="you@example.com"
                value={email}
                onChange={(e) => { setEmail(e.target.value); setErrors((p) => ({ ...p, email: null })); }}
                autoComplete="email"
              />
              {errors.email && <p className="form-error">{errors.email}</p>}
            </div>

            {errors.form && (
              <p className="form-error" style={{ marginBottom: "16px", textAlign: "center" }}>
                {errors.form}
              </p>
            )}

            <button
              type="submit"
              className="btn btn-primary w-full btn-lg"
              disabled={submitting}
            >
              {submitting ? <><LuLoader className="spinner-sm" style={{ animation: "spin 0.8s linear infinite" }} /> Sending...</> : "Send Reset Link"}
            </button>
          </form>
        </div>

        <div className="auth-footer">
          <Link to="/login" style={{ display: "inline-flex", alignItems: "center", gap: "6px" }}>
            <LuArrowLeft size={16} /> Back to Login
          </Link>
        </div>
      </div>
    </div>
  );
}
