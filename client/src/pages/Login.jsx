import { useState } from "react";
import { Link, Navigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { validateEmail, validatePassword } from "../utils/validators";
import { LuEye, LuEyeOff, LuLoader } from "react-icons/lu";

const REDIRECT_MAP = {
  user: "/user/dashboard",
  volunteer: "/volunteer/dashboard",
  organizer: "/organizer/dashboard",
};

export default function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [errors, setErrors] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const { login, user } = useAuth();
  const toast = useToast();

  // If already authenticated, redirect to dashboard
  if (user && user.user_type) {
    return <Navigate to={REDIRECT_MAP[user.user_type] || "/"} replace />;
  }

  const validate = () => {
    const newErrors = {};
    const emailErr = validateEmail(email);
    if (emailErr) newErrors.email = emailErr;
    if (!password) newErrors.password = "Password is required";
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validate()) return;

    setSubmitting(true);
    try {
      await login(email, password);
      toast("Login successful. Welcome back!", "success");
      // Navigation happens automatically via the redirect above
      // once onAuthStateChange fires and sets user state
    } catch (err) {
      toast(err.message || "Login failed", "error");
      setErrors({ form: err.message });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="auth-page">
      <div className="auth-container">
        <div className="auth-logo">
          <h1>Spatial<span style={{ color: "var(--text-primary)" }}>Ly</span></h1>
          <p>Real-time crowd intelligence</p>
        </div>

        <div className="auth-card">
          <h2>Welcome back</h2>
          <p className="auth-subtitle">Log in with your User ID, Volunteer ID, or Organizer email</p>

          <form onSubmit={handleSubmit} autoComplete="off" noValidate>
            <div className="form-group">
              <label className="form-label" htmlFor="login-email">Email Address</label>
              <input
                id="login-email"
                type="email"
                className={`form-input ${errors.email ? "error" : ""}`}
                placeholder="you@example.com"
                value={email}
                onChange={(e) => { setEmail(e.target.value); setErrors((p) => ({ ...p, email: null })); }}
                autoComplete="username"
                spellCheck="false"
              />
              {errors.email && <p className="form-error">{errors.email}</p>}
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="login-password">Password</label>
              <div className="password-input-wrapper">
                <input
                  id="login-password"
                  type={showPassword ? "text" : "password"}
                  className={`form-input ${errors.password ? "error" : ""}`}
                  placeholder="Enter your password"
                  value={password}
                  onChange={(e) => { setPassword(e.target.value); setErrors((p) => ({ ...p, password: null })); }}
                  autoComplete="current-password"
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
              {errors.password && <p className="form-error">{errors.password}</p>}
              <div style={{ marginTop: "8px", textAlign: "right" }}>
                <Link to="/forgot-password" style={{ fontSize: "0.85rem", color: "var(--green-400)", textDecoration: "none" }}>Forgot Password?</Link>
              </div>
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
              {submitting ? <><LuLoader className="spinner-sm" style={{ animation: "spin 0.8s linear infinite" }} /> Logging in...</> : "Log In"}
            </button>
          </form>
        </div>

        <div className="auth-footer">
          <p>
            New to SpatialLy? <Link to="/signup">Create an account</Link>
          </p>
        </div>
      </div>
    </div>
  );
}
