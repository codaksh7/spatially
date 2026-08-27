import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { validateEmail, validatePassword, validateName } from "../utils/validators";
import { LuEye, LuEyeOff, LuLoader, LuCircleCheck } from "react-icons/lu";

export default function Signup() {
  const [form, setForm] = useState({ email: "", password: "", full_name: "", nickname: "" });
  const [showPassword, setShowPassword] = useState(false);
  const [errors, setErrors] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);
  const { signup } = useAuth();
  const navigate = useNavigate();
  const toast = useToast();

  const updateField = (field, value) => {
    setForm((prev) => ({ ...prev, [field]: value }));
    setErrors((prev) => ({ ...prev, [field]: null }));
  };

  const validate = () => {
    const newErrors = {};
    const nameErr = validateName(form.full_name);
    if (nameErr) newErrors.full_name = nameErr;
    const emailErr = validateEmail(form.email);
    if (emailErr) newErrors.email = emailErr;
    const pwErr = validatePassword(form.password);
    if (pwErr) newErrors.password = pwErr;
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validate()) return;

    setSubmitting(true);
    try {
      await signup(form.email, form.password, form.full_name, form.nickname);
      setSuccess(true);
      toast("Account created! Check your email for the verification link.", "success");
    } catch (err) {
      toast(err.message || "Signup failed", "error");
      setErrors({ form: err.message });
    } finally {
      setSubmitting(false);
    }
  };

  if (success) {
    return (
      <div className="auth-page">
        <div className="auth-container" style={{ textAlign: "center" }}>
          <div style={{ marginBottom: "24px" }}>
            <LuCircleCheck size={56} color="var(--green-400)" />
          </div>
          <h2 style={{ marginBottom: "12px" }}>Verify Your Email</h2>
          <p style={{ color: "var(--text-secondary)", marginBottom: "24px", lineHeight: "1.6" }}>
            We have sent a verification link to <strong style={{ color: "var(--text-primary)" }}>{form.email}</strong>.
            Please check your inbox and click the link to activate your account.
          </p>
          <Link to="/login" className="btn btn-primary">
            Go to Login
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="auth-page">
      <div className="auth-container">
        <div className="auth-logo">
          <h1>Spatial<span style={{ color: "var(--text-primary)" }}>Ly</span></h1>
          <p>Create your account</p>
        </div>

        <div className="auth-card">
          <h2>Sign Up</h2>
          <p className="auth-subtitle">Join as an attendee to browse and register for events</p>

          <form onSubmit={handleSubmit} autoComplete="off" noValidate>
            <div className="form-group">
              <label className="form-label" htmlFor="signup-name">Full Name</label>
              <input
                id="signup-name"
                type="text"
                className={`form-input ${errors.full_name ? "error" : ""}`}
                placeholder="Daksh Thakkar"
                value={form.full_name}
                onChange={(e) => updateField("full_name", e.target.value)}
              />
              {errors.full_name && <p className="form-error">{errors.full_name}</p>}
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="signup-nickname">Nickname (optional)</label>
              <input
                id="signup-nickname"
                type="text"
                className="form-input"
                placeholder="daksh"
                value={form.nickname}
                onChange={(e) => updateField("nickname", e.target.value)}
              />
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="signup-email">Email Address</label>
              <input
                id="signup-email"
                type="email"
                className={`form-input ${errors.email ? "error" : ""}`}
                placeholder="you@example.com"
                value={form.email}
                onChange={(e) => updateField("email", e.target.value)}
                spellCheck="false"
              />
              {errors.email && <p className="form-error">{errors.email}</p>}
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="signup-password">Password</label>
              <div className="password-input-wrapper">
                <input
                  id="signup-password"
                  type={showPassword ? "text" : "password"}
                  className={`form-input ${errors.password ? "error" : ""}`}
                  placeholder="Min 8 chars, upper, lower, number, #@$"
                  value={form.password}
                  onChange={(e) => updateField("password", e.target.value)}
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
              <p style={{ fontSize: "0.725rem", color: "var(--text-muted)", marginTop: "4px" }}>
                Must contain uppercase, lowercase, number, and one of #, @, $
              </p>
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
              {submitting ? <><LuLoader style={{ animation: "spin 0.8s linear infinite" }} /> Creating account...</> : "Create Account"}
            </button>
          </form>
        </div>

        <div className="auth-footer">
          <p>
            Already have an account? <Link to="/login">Log in</Link>
          </p>
        </div>
      </div>
    </div>
  );
}
