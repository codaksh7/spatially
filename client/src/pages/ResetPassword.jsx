import { useState, useEffect } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { api } from "../utils/api";
import { useToast } from "../components/Toast";
import { validatePassword } from "../utils/validators";
import { LuEye, LuEyeOff, LuLoader, LuCheck, LuTriangleAlert } from "react-icons/lu";

export default function ResetPassword() {
  const [searchParams] = useSearchParams();
  const token = searchParams.get("token");
  
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  
  const [errors, setErrors] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);
  
  const navigate = useNavigate();
  const toast = useToast();

  useEffect(() => {
    if (!token) {
      setErrors({ global: "Invalid or missing reset token. Please request a new password reset link." });
    }
  }, [token]);

  const validate = () => {
    const newErrors = {};
    const passErr = validatePassword(newPassword);
    if (passErr) newErrors.newPassword = passErr;
    
    if (newPassword !== confirmPassword) {
      newErrors.confirmPassword = "Passwords do not match";
    }
    
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!token) return;
    if (!validate()) return;
    
    setSubmitting(true);
    
    try {
      await api.post("/api/auth/reset-password", { 
        token, 
        new_password: newPassword, 
        confirm_password: confirmPassword 
      });
      setSuccess(true);
      toast("Password reset successful", "success");
    } catch (err) {
      setErrors({ form: err.message || "Failed to reset password. The link may have expired." });
    } finally {
      setSubmitting(false);
    }
  };

  if (!token) {
    return (
      <div className="auth-page">
        <div className="auth-container">
          <div className="auth-card" style={{ textAlign: "center" }}>
            <LuTriangleAlert size={48} style={{ color: "var(--danger)", margin: "0 auto 16px" }} />
            <h2 style={{ marginBottom: "12px" }}>Invalid Link</h2>
            <p className="auth-subtitle" style={{ marginBottom: "24px" }}>
              This password reset link is invalid or missing the required token.
            </p>
            <Link to="/forgot-password" className="btn btn-primary w-full">Request New Link</Link>
          </div>
        </div>
      </div>
    );
  }

  if (success) {
    return (
      <div className="auth-page">
        <div className="auth-container">
          <div className="auth-logo">
            <h1>Spatial<span style={{ color: "var(--text-primary)" }}>Ly</span></h1>
          </div>
          <div className="auth-card" style={{ textAlign: "center" }}>
            <LuCheck size={48} style={{ color: "var(--green-400)", margin: "0 auto 16px" }} />
            <h2 style={{ marginBottom: "12px" }}>Password Updated</h2>
            <p className="auth-subtitle" style={{ marginBottom: "24px", lineHeight: "1.6" }}>
              Your password has been successfully reset. You can now log in with your new credentials.
            </p>
            <button onClick={() => navigate("/login")} className="btn btn-primary w-full">Go to Login</button>
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
        </div>

        <div className="auth-card">
          <h2>Create New Password</h2>
          <p className="auth-subtitle">Please enter your new password below.</p>

          <form onSubmit={handleSubmit} noValidate>
            <div className="form-group">
              <label className="form-label" htmlFor="new-password">New Password</label>
              <div className="password-input-wrapper">
                <input
                  id="new-password"
                  type={showPassword ? "text" : "password"}
                  className={`form-input ${errors.newPassword ? "error" : ""}`}
                  placeholder="Enter new password"
                  value={newPassword}
                  onChange={(e) => { setNewPassword(e.target.value); setErrors((p) => ({ ...p, newPassword: null })); }}
                />
                <button
                  type="button"
                  className="password-toggle"
                  onClick={() => setShowPassword(!showPassword)}
                  tabIndex={-1}
                  aria-label={showPassword ? "Hide password" : "Show password"}
                >
                  {showPassword ? <LuEyeOff size={18} /> : <LuEye size={18} />}
                </button>
              </div>
              {errors.newPassword && <p className="form-error">{errors.newPassword}</p>}
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="confirm-password">Confirm Password</label>
              <div className="password-input-wrapper">
                <input
                  id="confirm-password"
                  type={showConfirmPassword ? "text" : "password"}
                  className={`form-input ${errors.confirmPassword ? "error" : ""}`}
                  placeholder="Confirm new password"
                  value={confirmPassword}
                  onChange={(e) => { setConfirmPassword(e.target.value); setErrors((p) => ({ ...p, confirmPassword: null })); }}
                />
                <button
                  type="button"
                  className="password-toggle"
                  onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                  tabIndex={-1}
                  aria-label={showConfirmPassword ? "Hide password" : "Show password"}
                >
                  {showConfirmPassword ? <LuEyeOff size={18} /> : <LuEye size={18} />}
                </button>
              </div>
              {errors.confirmPassword && <p className="form-error">{errors.confirmPassword}</p>}
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
              {submitting ? <><LuLoader className="spinner-sm" style={{ animation: "spin 0.8s linear infinite" }} /> Updating...</> : "Update Password"}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
