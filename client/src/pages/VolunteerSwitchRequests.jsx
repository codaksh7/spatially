import { useState, useEffect } from "react";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { LuArrowLeftRight, LuCheck, LuX, LuInbox, LuSend } from "react-icons/lu";

export default function VolunteerSwitchRequests() {
  const { user } = useAuth();
  const toast = useToast();
  const [incoming, setIncoming] = useState([]);
  const [outgoing, setOutgoing] = useState([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(null);

  useEffect(() => {
    fetchRequests();
  }, []);

  async function fetchRequests() {
    try {
      const res = await api.get("/api/venue-map/my-switch-requests");
      setIncoming(res.incoming || []);
      setOutgoing(res.outgoing || []);
    } catch (err) {
      toast(err.message, "error");
    } finally {
      setLoading(false);
    }
  }

  async function handleAction(requestId, action) {
    setActionLoading(requestId);
    try {
      await api.post(`/api/venue-map/switch-request/${requestId}/${action}`);
      toast(action === "accept" ? "Positions switched successfully!" : "Request declined", action === "accept" ? "success" : "info");
      fetchRequests();
    } catch (err) {
      toast(err.message, "error");
    } finally {
      setActionLoading(null);
    }
  }

  if (loading) {
    return <div className="loading-screen" style={{ minHeight: "60vh" }}><div className="spinner"></div></div>;
  }

  return (
    <div className="fade-in">
      <div className="page-header">
        <h1 style={{ display: "flex", alignItems: "center", gap: "10px" }}>
          <LuArrowLeftRight /> Switch Requests
        </h1>
      </div>

      {/* Incoming Requests */}
      <div className="card" style={{ marginBottom: "24px" }}>
        <div className="section-header">
          <h3 className="section-title" style={{ display: "flex", alignItems: "center", gap: "8px" }}>
            <LuInbox size={18} color="var(--green-400)" /> Incoming Requests
          </h3>
          {incoming.length > 0 && <span className="badge badge-pending">{incoming.length} pending</span>}
        </div>

        {incoming.length === 0 ? (
          <div style={{ textAlign: "center", padding: "24px", color: "var(--text-muted)", fontSize: "0.85rem" }}>
            No incoming switch requests.
          </div>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
            {incoming.map((req) => (
              <div key={req.id} className="switch-page-item">
                <div className="switch-page-item-info">
                  <div className="switch-page-dot incoming"></div>
                  <div>
                    <div style={{ fontWeight: "600", fontSize: "0.9rem" }}>{req.requester_name || req.requester_id}</div>
                    <div style={{ color: "var(--text-muted)", fontSize: "0.8rem" }}>
                      {req.requester_id} wants to switch positions • {req.event_name}
                    </div>
                  </div>
                </div>
                <div style={{ display: "flex", gap: "8px", flexShrink: 0 }}>
                  <button
                    className="btn btn-sm btn-primary"
                    disabled={actionLoading === req.id}
                    onClick={() => handleAction(req.id, "accept")}
                  >
                    {actionLoading === req.id ? <div className="spinner spinner-sm"></div> : <><LuCheck size={14} /> Accept</>}
                  </button>
                  <button
                    className="btn btn-sm btn-danger"
                    disabled={actionLoading === req.id}
                    onClick={() => handleAction(req.id, "decline")}
                  >
                    <LuX size={14} />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Outgoing Requests */}
      <div className="card">
        <div className="section-header">
          <h3 className="section-title" style={{ display: "flex", alignItems: "center", gap: "8px" }}>
            <LuSend size={18} color="var(--info)" /> Sent Requests
          </h3>
        </div>

        {outgoing.length === 0 ? (
          <div style={{ textAlign: "center", padding: "24px", color: "var(--text-muted)", fontSize: "0.85rem" }}>
            No outgoing switch requests.
          </div>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
            {outgoing.map((req) => (
              <div key={req.id} className="switch-page-item">
                <div className="switch-page-item-info">
                  <div className="switch-page-dot outgoing"></div>
                  <div>
                    <div style={{ fontWeight: "600", fontSize: "0.9rem" }}>{req.target_name || req.target_id}</div>
                    <div style={{ color: "var(--text-muted)", fontSize: "0.8rem" }}>
                      Waiting for {req.target_id} to respond • {req.event_name}
                    </div>
                  </div>
                </div>
                <span className="badge badge-pending">Pending</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
