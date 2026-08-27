import { useState } from "react";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { LuUser, LuMail, LuHash, LuSave, LuLoader, LuLock, LuX } from "react-icons/lu";
import { api } from "../utils/api";

export default function Profile() {
  const { user, updateProfile } = useAuth();
  const toast = useToast();
  const [form, setForm] = useState({
    full_name: user?.full_name || "",
    nickname: user?.nickname || "",
  });
  const [submitting, setSubmitting] = useState(false);

  const [pwdModalOpen, setPwdModalOpen] = useState(false);
  const [pwdForm, setPwdForm] = useState({
    current_password: "",
    new_password: "",
    confirm_password: "",
  });
  const [pwdSubmitting, setPwdSubmitting] = useState(false);
  const [pwdErrors, setPwdErrors] = useState({});

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!form.full_name.trim()) {
      toast("Full name is required", "error");
      return;
    }

    setSubmitting(true);
    try {
      await updateProfile({ full_name: form.full_name, nickname: form.nickname });
      toast("Profile updated successfully", "success");
    } catch (err) {
      toast(err.message || "Failed to update profile", "error");
    } finally {
      setSubmitting(false);
    }
  };

  const handlePasswordSubmit = async (e) => {
    e.preventDefault();
    if (!pwdForm.current_password) return setPwdErrors({ current_password: "Required" });
    if (!pwdForm.new_password) return setPwdErrors({ new_password: "Required" });
    if (pwdForm.new_password !== pwdForm.confirm_password) {
      return setPwdErrors({ confirm_password: "Passwords do not match" });
    }

    setPwdErrors({});
    setPwdSubmitting(true);
    try {
      await api.post("/api/auth/update-password", {
        current_password: pwdForm.current_password,
        new_password: pwdForm.new_password,
      });
      toast("Password updated successfully", "success");
      setPwdModalOpen(false);
      setPwdForm({ current_password: "", new_password: "", confirm_password: "" });
    } catch (err) {
      toast(err.message || "Failed to update password", "error");
    } finally {
      setPwdSubmitting(false);
    }
  };

  return (
    <div className="fade-in" style={{ maxWidth: "900px", margin: "0 auto" }}>
      <div className="page-header">
        <h1>Profile</h1>
        <button className="btn btn-secondary" onClick={() => setPwdModalOpen(true)}>
          <LuLock size={14} /> Update Password
        </button>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(350px, 1fr))", gap: "24px" }}>
        <div className="card">
          <h3 className="card-title" style={{ marginBottom: "20px" }}>Account Information</h3>

          <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
            <div style={{ display: "flex", alignItems: "center", gap: "12px", padding: "12px", backgroundColor: "var(--bg-tertiary)", borderRadius: "var(--radius-md)" }}>
              <LuHash size={18} color="var(--green-400)" />
              <div>
                <div style={{ fontSize: "0.725rem", color: "var(--text-muted)" }}>User ID</div>
                <div style={{ fontSize: "0.9rem", fontWeight: 600 }}>{user?.user_id}</div>
              </div>
            </div>

            <div style={{ display: "flex", alignItems: "center", gap: "12px", padding: "12px", backgroundColor: "var(--bg-tertiary)", borderRadius: "var(--radius-md)" }}>
              <LuMail size={18} color="var(--green-400)" />
              <div>
                <div style={{ fontSize: "0.725rem", color: "var(--text-muted)" }}>Email</div>
                <div style={{ fontSize: "0.9rem", fontWeight: 600 }}>{user?.email}</div>
              </div>
            </div>

            <div style={{ display: "flex", alignItems: "center", gap: "12px", padding: "12px", backgroundColor: "var(--bg-tertiary)", borderRadius: "var(--radius-md)" }}>
              <LuUser size={18} color="var(--green-400)" />
              <div>
                <div style={{ fontSize: "0.725rem", color: "var(--text-muted)" }}>Account Type</div>
                <div style={{ fontSize: "0.9rem", fontWeight: 600, textTransform: "capitalize" }}>{user?.user_type}</div>
              </div>
            </div>
          </div>
        </div>

        <div className="card">
          <h3 className="card-title" style={{ marginBottom: "20px" }}>Edit Profile</h3>

          <form onSubmit={handleSubmit} noValidate>
            <div className="form-group">
              <label className="form-label" htmlFor="profile-name">Full Name</label>
              <input
                id="profile-name"
                type="text"
                className="form-input"
                value={form.full_name}
                onChange={(e) => setForm((p) => ({ ...p, full_name: e.target.value }))}
              />
            </div>
            <div className="form-group">
              <label className="form-label" htmlFor="profile-nickname">Nickname</label>
              <input
                id="profile-nickname"
                type="text"
                className="form-input"
                value={form.nickname}
                onChange={(e) => setForm((p) => ({ ...p, nickname: e.target.value }))}
              />
            </div>
            <button type="submit" className="btn btn-primary" disabled={submitting}>
              {submitting ? <LuLoader style={{ animation: "spin 0.8s linear infinite" }} /> : <LuSave size={14} />}
              Save Changes
            </button>
          </form>
        </div>
      </div>

      {pwdModalOpen && (
        <div className="modal-overlay" onClick={() => setPwdModalOpen(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3 style={{ fontSize: "1.1rem", fontWeight: 600 }}>Update Password</h3>
              <button className="btn-icon" onClick={() => setPwdModalOpen(false)} style={{ background: "none", border: "none", color: "var(--text-muted)" }}>
                <LuX size={20} />
              </button>
            </div>
            <div className="modal-body">
              <form id="pwd-form" onSubmit={handlePasswordSubmit}>
                <div className="form-group">
                  <label className="form-label">Current Password</label>
                  <input
                    type="password"
                    className={`form-input ${pwdErrors.current_password ? "error" : ""}`}
                    value={pwdForm.current_password}
                    onChange={(e) => { setPwdForm({ ...pwdForm, current_password: e.target.value }); setPwdErrors({}); }}
                  />
                  {pwdErrors.current_password && <p className="form-error">{pwdErrors.current_password}</p>}
                </div>
                <div className="form-group">
                  <label className="form-label">New Password</label>
                  <input
                    type="password"
                    className={`form-input ${pwdErrors.new_password ? "error" : ""}`}
                    value={pwdForm.new_password}
                    onChange={(e) => { setPwdForm({ ...pwdForm, new_password: e.target.value }); setPwdErrors({}); }}
                  />
                  <p style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "4px" }}>
                    Must be at least 8 characters long, contain uppercase, lowercase, number and special char (#, @, $).
                  </p>
                  {pwdErrors.new_password && <p className="form-error">{pwdErrors.new_password}</p>}
                </div>
                <div className="form-group">
                  <label className="form-label">Confirm New Password</label>
                  <input
                    type="password"
                    className={`form-input ${pwdErrors.confirm_password ? "error" : ""}`}
                    value={pwdForm.confirm_password}
                    onChange={(e) => { setPwdForm({ ...pwdForm, confirm_password: e.target.value }); setPwdErrors({}); }}
                  />
                  {pwdErrors.confirm_password && <p className="form-error">{pwdErrors.confirm_password}</p>}
                </div>
              </form>
            </div>
            <div className="modal-footer">
              <button type="button" className="btn btn-secondary" onClick={() => setPwdModalOpen(false)}>Cancel</button>
              <button type="submit" form="pwd-form" className="btn btn-primary" disabled={pwdSubmitting}>
                {pwdSubmitting ? "Updating..." : "Update Password"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
