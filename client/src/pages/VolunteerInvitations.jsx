import { useEffect, useState } from "react";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { LuCheck, LuX, LuMail, LuCalendarDays } from "react-icons/lu";

export default function VolunteerInvitations() {
  const toast = useToast();
  const [invitations, setInvitations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [processing, setProcessing] = useState(null);

  useEffect(() => {
    api.get("/api/volunteers/my-invitations")
      .then((data) => setInvitations(data.invitations || []))
      .catch((err) => toast(err.message, "error"))
      .finally(() => setLoading(false));
  }, []);

  const handleAccept = async (invId) => {
    setProcessing(invId);
    try {
      await api.post(`/api/volunteers/invitations/${invId}/accept`);
      setInvitations((prev) => prev.filter((i) => i.id !== invId));
      toast("Invitation accepted! You are now assigned to the event.", "success");
    } catch (err) {
      toast(err.message, "error");
    } finally {
      setProcessing(null);
    }
  };

  const handleDecline = async (invId) => {
    setProcessing(invId);
    try {
      await api.post(`/api/volunteers/invitations/${invId}/decline`);
      setInvitations((prev) => prev.filter((i) => i.id !== invId));
      toast("Invitation declined", "info");
    } catch (err) {
      toast(err.message, "error");
    } finally {
      setProcessing(null);
    }
  };

  if (loading) {
    return <div className="loading-screen" style={{ minHeight: "60vh" }}><div className="spinner"></div></div>;
  }

  return (
    <div className="fade-in">
      <div className="page-header">
        <h1>Invitations</h1>
      </div>

      {invitations.length > 0 ? (
        <div className="events-grid">
          {invitations.map((inv) => (
            <div key={inv.id} className="event-card" style={{ borderColor: "var(--warning)" }}>
              <div className="event-card-header">
                <div className="event-card-title">{inv.event?.name || "Event Invitation"}</div>
                <span className="badge badge-pending">Pending</span>
              </div>
              {inv.event && (
                <div className="event-card-meta">
                  <div className="event-card-meta-item">
                    <LuCalendarDays className="meta-icon" size={14} />
                    {inv.event.venue} &middot; {inv.event.event_date?.slice(0, 10)}
                  </div>
                </div>
              )}
              <p style={{ fontSize: "0.8rem", color: "var(--text-muted)", margin: "8px 0" }}>
                Invited by: {inv.invited_by}
              </p>
              <div className="event-card-footer">
                <button
                  className="btn btn-primary btn-sm"
                  onClick={() => handleAccept(inv.id)}
                  disabled={processing === inv.id}
                >
                  <LuCheck size={14} /> Accept
                </button>
                <button
                  className="btn btn-ghost btn-sm"
                  style={{ color: "var(--error)" }}
                  onClick={() => handleDecline(inv.id)}
                  disabled={processing === inv.id}
                >
                  <LuX size={14} /> Decline
                </button>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="empty-state">
          <div className="empty-state-icon"><LuMail /></div>
          <div className="empty-state-title">No pending invitations</div>
          <div className="empty-state-text">When an organizer invites you to an event, it will appear here.</div>
        </div>
      )}
    </div>
  );
}
