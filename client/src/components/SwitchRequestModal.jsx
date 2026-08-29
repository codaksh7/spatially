import { useState, useEffect } from "react";
import { api } from "../utils/api";
import { useToast } from "./Toast";
import { LuArrowLeftRight, LuCheck, LuX, LuSend, LuInbox } from "react-icons/lu";

export default function SwitchRequestModal({ eventId, currentUserId, volPositions = [], onClose, onSwitch }) {
  const toast = useToast();
  const [activeTab, setActiveTab] = useState("request"); // "request" | "incoming" | "outgoing"
  const [incoming, setIncoming] = useState([]);
  const [outgoing, setOutgoing] = useState([]);
  const [loadingId, setLoadingId] = useState(null);
  const [fetching, setFetching] = useState(true);

  const otherVolunteers = volPositions.filter((v) => v.volunteer_user_id !== currentUserId);

  useEffect(() => {
    fetchRequests();
  }, []);

  async function fetchRequests() {
    try {
      const res = await api.get("/api/venue-map/my-switch-requests");
      setIncoming((res.incoming || []).filter((r) => r.event_id === eventId));
      setOutgoing((res.outgoing || []).filter((r) => r.event_id === eventId));
    } catch (err) {
      toast(err.message, "error");
    } finally {
      setFetching(false);
    }
  }

  async function sendRequest(targetId) {
    setLoadingId(targetId);
    try {
      await api.post(`/api/venue-map/${eventId}/switch-request`, {
        target_volunteer_id: targetId,
      });
      toast("Switch request sent!", "success");
      fetchRequests();
    } catch (err) {
      toast(err.message, "error");
    } finally {
      setLoadingId(null);
    }
  }

  async function respondRequest(requestId, action) {
    setLoadingId(requestId);
    try {
      await api.post(`/api/venue-map/switch-request/${requestId}/${action}`);
      toast(action === "accept" ? "Positions switched!" : "Request declined", action === "accept" ? "success" : "info");
      fetchRequests();
      if (action === "accept" && onSwitch) onSwitch();
    } catch (err) {
      toast(err.message, "error");
    } finally {
      setLoadingId(null);
    }
  }

  const pendingTargetIds = new Set(outgoing.map((r) => r.target_id));

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: "560px" }}>
        <div className="modal-header">
          <h3 style={{ display: "flex", alignItems: "center", gap: "8px", fontSize: "1.1rem" }}>
            <LuArrowLeftRight size={20} /> Switch Positions
          </h3>
          <button className="btn btn-icon btn-ghost" onClick={onClose}>
            <LuX size={18} />
          </button>
        </div>

        {/* Tabs */}
        <div className="switch-modal-tabs">
          <button
            className={`switch-modal-tab ${activeTab === "request" ? "active" : ""}`}
            onClick={() => setActiveTab("request")}
          >
            <LuSend size={14} /> Request
          </button>
          <button
            className={`switch-modal-tab ${activeTab === "incoming" ? "active" : ""}`}
            onClick={() => setActiveTab("incoming")}
          >
            <LuInbox size={14} /> Incoming
            {incoming.length > 0 && <span className="switch-badge">{incoming.length}</span>}
          </button>
          <button
            className={`switch-modal-tab ${activeTab === "outgoing" ? "active" : ""}`}
            onClick={() => setActiveTab("outgoing")}
          >
            <LuSend size={14} /> Sent
            {outgoing.length > 0 && <span className="switch-badge">{outgoing.length}</span>}
          </button>
        </div>

        <div className="modal-body" style={{ maxHeight: "400px", overflowY: "auto" }}>
          {fetching ? (
            <div style={{ textAlign: "center", padding: "24px" }}>
              <div className="spinner"></div>
            </div>
          ) : (
            <>
              {/* REQUEST TAB */}
              {activeTab === "request" && (
                <div className="switch-request-list">
                  {otherVolunteers.length === 0 ? (
                    <div className="switch-empty">No other volunteers placed on this map yet.</div>
                  ) : (
                    otherVolunteers.map((v) => {
                      const isPending = pendingTargetIds.has(v.volunteer_user_id);
                      return (
                        <div key={v.volunteer_user_id} className="switch-request-item">
                          <div className="switch-request-info">
                            <div className="switch-request-dot"></div>
                            <div>
                              <div className="switch-request-name">{v.volunteer_name || v.volunteer_user_id}</div>
                              <div className="switch-request-meta">
                                {v.volunteer_user_id} • Zone {v.zone}
                              </div>
                            </div>
                          </div>
                          {isPending ? (
                            <span className="badge badge-pending">Pending</span>
                          ) : (
                            <button
                              className="btn btn-sm btn-secondary"
                              disabled={loadingId === v.volunteer_user_id}
                              onClick={() => sendRequest(v.volunteer_user_id)}
                            >
                              {loadingId === v.volunteer_user_id ? (
                                <div className="spinner spinner-sm"></div>
                              ) : (
                                <>
                                  <LuArrowLeftRight size={12} /> Switch
                                </>
                              )}
                            </button>
                          )}
                        </div>
                      );
                    })
                  )}
                </div>
              )}

              {/* INCOMING TAB */}
              {activeTab === "incoming" && (
                <div className="switch-request-list">
                  {incoming.length === 0 ? (
                    <div className="switch-empty">No incoming switch requests.</div>
                  ) : (
                    incoming.map((req) => (
                      <div key={req.id} className="switch-request-item">
                        <div className="switch-request-info">
                          <div className="switch-request-dot incoming"></div>
                          <div>
                            <div className="switch-request-name">{req.requester_name || req.requester_id}</div>
                            <div className="switch-request-meta">
                              {req.requester_id} wants to switch positions
                            </div>
                          </div>
                        </div>
                        <div style={{ display: "flex", gap: "6px" }}>
                          <button
                            className="btn btn-sm btn-primary"
                            disabled={loadingId === req.id}
                            onClick={() => respondRequest(req.id, "accept")}
                          >
                            <LuCheck size={14} /> Accept
                          </button>
                          <button
                            className="btn btn-sm btn-danger"
                            disabled={loadingId === req.id}
                            onClick={() => respondRequest(req.id, "decline")}
                          >
                            <LuX size={14} />
                          </button>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              )}

              {/* OUTGOING TAB */}
              {activeTab === "outgoing" && (
                <div className="switch-request-list">
                  {outgoing.length === 0 ? (
                    <div className="switch-empty">No outgoing switch requests.</div>
                  ) : (
                    outgoing.map((req) => (
                      <div key={req.id} className="switch-request-item">
                        <div className="switch-request-info">
                          <div className="switch-request-dot outgoing"></div>
                          <div>
                            <div className="switch-request-name">{req.target_name || req.target_id}</div>
                            <div className="switch-request-meta">
                              Waiting for {req.target_id} to respond
                            </div>
                          </div>
                        </div>
                        <span className="badge badge-pending">Pending</span>
                      </div>
                    ))
                  )}
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}
