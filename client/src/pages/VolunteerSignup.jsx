import { useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { validateEmail, validatePassword, validateName } from "../utils/validators";
import { LuEye, LuEyeOff, LuLoader } from "react-icons/lu";

export default function VolunteerSignup() {
  const [searchParams] = useSearchParams();
  const tokenFromUrl = searchParams.get("token") || "";
  const emailFromUrl = searchParams.get("email") || "";

  const [form, setForm] = useState({
    email: emailFromUrl,
    password: "",
    full_name: "",
    nickname: "",
    invitation_token: tokenFromUrl,
  });
  const [showPassword, setShowPassword] = useState(false);
  const [errors, setErrors] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const { volunteerSignup } = useAuth();
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
    if (!form.invitation_token) newErrors.invitation_token = "Invitation token is required";
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validate()) return;

    setSubmitting(true);
    try {
      await volunteerSignup(
        form.email,
        form.password,
        form.full_name,
        form.nickname,
        form.invitation_token
      );
      toast("Volunteer account created! You can now log in.", "success");
      navigate("/login");
    } catch (err) {
      toast(err.message || "Signup failed", "error");
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
          <p>Volunteer Registration</p>
        </div>

        <div className="auth-card">
          <h2>Accept Invitation</h2>
          <p className="auth-subtitle">
            Set up your volunteer account to get started
          </p>

          <form onSubmit={handleSubmit} autoComplete="off" noValidate>
            <div className="form-group">
              <label className="form-label" htmlFor="vol-name">Full Name</label>
              <input
                id="vol-name"
                type="text"
                className={`form-input ${errors.full_name ? "error" : ""}`}
                placeholder="Your full name"
                value={form.full_name}
                onChange={(e) => updateField("full_name", e.target.value)}
              />
              {errors.full_name && <p className="form-error">{errors.full_name}</p>}
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="vol-nickname">Nickname</label>
              <input
                id="vol-nickname"
                type="text"
                className="form-input"
                placeholder="How you want to be called"
                value={form.nickname}
                onChange={(e) => updateField("nickname", e.target.value)}
              />
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="vol-email">Email Address</label>
              <input
                id="vol-email"
                type="email"
                className={`form-input ${errors.email ? "error" : ""}`}
                value={form.email}
                disabled={!!emailFromUrl}
                onChange={(e) => updateField("email", e.target.value)}
                spellCheck="false"
              />
              {emailFromUrl && (
                <p style={{ fontSize: "0.725rem", color: "var(--text-muted)", marginTop: "4px" }}>
                  Email is set from your invitation and cannot be changed
                </p>
              )}
              {errors.email && <p className="form-error">{errors.email}</p>}
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="vol-password">Password</label>
              <div className="password-input-wrapper">
                <input
                  id="vol-password"
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
            </div>

            {!tokenFromUrl && (
              <div className="form-group">
                <label className="form-label" htmlFor="vol-token">Invitation Token</label>
                <input
                  id="vol-token"
                  type="text"
                  className={`form-input ${errors.invitation_token ? "error" : ""}`}
                  placeholder="Paste your invitation token"
                  value={form.invitation_token}
                  onChange={(e) => updateField("invitation_token", e.target.value)}
                />
                {errors.invitation_token && <p className="form-error">{errors.invitation_token}</p>}
              </div>
            )}

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
              {submitting ? <><LuLoader style={{ animation: "spin 0.8s linear infinite" }} /> Creating account...</> : "Create Volunteer Account"}
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
