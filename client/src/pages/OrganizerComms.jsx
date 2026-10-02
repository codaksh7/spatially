import { useEffect, useState } from "react";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { LuMail, LuSend, LuUsers, LuMapPin, LuMegaphone, LuCheckCheck } from "react-icons/lu";

export default function OrganizerComms() {
  const { user } = useAuth();
  const toast = useToast();
  const [events, setEvents] = useState([]);
  const [selectedEventId, setSelectedEventId] = useState("");
  const [messages, setMessages] = useState([]);
  const [loading, setLoading] = useState(true);

  // Compose form state
  const [composeText, setComposeText] = useState("");
  const [targetType, setTargetType] = useState("broadcast");
  const [priority, setPriority] = useState("routine");
  const [requiresAck, setRequiresAck] = useState(false);
  const [isSending, setIsSending] = useState(false);

  useEffect(() => {
    api.get("/api/events/organizer/mine")
      .then((data) => {
        setEvents(data.events || []);
        if (data.events && data.events.length > 0) {
          const liveEvent = data.events.find(e => e.status === "live");
          if (liveEvent) {
            setSelectedEventId(liveEvent.id);
          } else {
            const upcomingEvent = data.events.find(e => e.status === "upcoming");
            if (upcomingEvent) {
              setSelectedEventId(upcomingEvent.id);
            } else {
              const endedEvents = data.events.filter(e => e.status === "ended");
              setSelectedEventId(endedEvents.length > 0 ? endedEvents[endedEvents.length - 1].id : data.events[0].id);
            }
          }
        } else {
          setLoading(false);
        }
      })
      .catch((err) => {
        toast(err.message, "error");
        setLoading(false);
      });
  }, []);

  useEffect(() => {
    if (!selectedEventId) return;
    fetchMessages();
  }, [selectedEventId]);

  const fetchMessages = () => {
    setLoading(true);
    api.get(`/api/organizer/comms/${selectedEventId}`)
      .then((data) => setMessages(data.messages || []))
      .catch((err) => toast(err.message, "error"))
      .finally(() => setLoading(false));
  };

  const handleSendMessage = async (e) => {
    e.preventDefault();
    if (!composeText.trim()) return;
    
    setIsSending(true);
    try {
      await api.post("/api/organizer/comms", {
        event_id: selectedEventId,
        content: composeText,
        target_type: targetType,
        priority: priority,
        requires_ack: requiresAck
      });
      toast("Message sent successfully", "success");
      setComposeText("");
      fetchMessages();
    } catch (err) {
      toast(err.message, "error");
    } finally {
      setIsSending(false);
    }
  };

  const getTargetIcon = (type) => {
    switch(type) {
      case "broadcast": return <LuMegaphone />;
      case "team": return <LuUsers />;
      case "zone": return <LuMapPin />;
      default: return <LuMail />;
    }
  };

  const getPriorityColor = (prio) => {
    switch(prio) {
      case "urgent": return "var(--error)";
      case "important": return "var(--warning)";
      default: return "var(--info)";
    }
  };

  return (
    <div className="fade-in">
      <div className="page-header">
        <div>
          <h1>Communications Console</h1>
          <p style={{ color: "var(--text-muted)", marginTop: "4px" }}>
            Broadcast alerts, team messages, and track acknowledgments.
          </p>
        </div>
        <div style={{ display: "flex", gap: "12px" }}>
          {events.length > 0 && (
            <select 
              className="form-select" 
              value={selectedEventId} 
              onChange={(e) => setSelectedEventId(e.target.value)}
              style={{ minWidth: "200px" }}
            >
              {events.map(ev => (
                <option key={ev.id} value={ev.id}>{ev.name} ({ev.status})</option>
              ))}
            </select>
          )}
        </div>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 2fr", gap: "24px" }}>
        
        {/* COMPOSE PANEL */}
        <div className="card" style={{ alignSelf: "start" }}>
          <div className="card-header">
            <h3 className="card-title">Compose Message</h3>
          </div>
          <div style={{ padding: "16px" }}>
            <form onSubmit={handleSendMessage}>
              <div className="form-group">
                <label className="form-label">Target</label>
                <select 
                  className="form-select" 
                  value={targetType}
                  onChange={(e) => setTargetType(e.target.value)}
                >
                  <option value="broadcast">Event-wide Broadcast</option>
                  <option value="team">Specific Team</option>
                  <option value="zone">Specific Zone</option>
                </select>
              </div>

              <div className="form-group">
                <label className="form-label">Priority</label>
                <div style={{ display: "flex", gap: "12px" }}>
                  <label style={{ display: "flex", alignItems: "center", gap: "6px", fontSize: "0.9rem" }}>
                    <input type="radio" name="priority" value="routine" checked={priority === "routine"} onChange={() => setPriority("routine")} /> Routine
                  </label>
                  <label style={{ display: "flex", alignItems: "center", gap: "6px", fontSize: "0.9rem" }}>
                    <input type="radio" name="priority" value="important" checked={priority === "important"} onChange={() => setPriority("important")} /> Important
                  </label>
                  <label style={{ display: "flex", alignItems: "center", gap: "6px", fontSize: "0.9rem", color: "var(--error)" }}>
                    <input type="radio" name="priority" value="urgent" checked={priority === "urgent"} onChange={() => setPriority("urgent")} /> Urgent
                  </label>
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Message Content</label>
                <textarea 
                  className="form-input"
                  style={{ minHeight: "120px", resize: "vertical" }}
                  placeholder="Enter message..."
                  value={composeText}
                  onChange={(e) => setComposeText(e.target.value)}
                  required
                ></textarea>
              </div>

              <div className="form-group">
                <label style={{ display: "flex", alignItems: "center", gap: "8px", fontSize: "0.9rem", cursor: "pointer" }}>
                  <input 
                    type="checkbox" 
                    checked={requiresAck}
                    onChange={(e) => setRequiresAck(e.target.checked)}
                  />
                  Require explicit acknowledgment (Read Receipts)
                </label>
              </div>

              <button 
                type="submit" 
                className="btn btn-primary" 
                style={{ width: "100%", justifyContent: "center", marginTop: "16px" }}
                disabled={isSending || !composeText.trim()}
              >
                {isSending ? <div className="spinner" style={{ width: "16px", height: "16px" }}></div> : <LuSend size={16} />}
                Dispatch Message
              </button>
            </form>
          </div>
        </div>

        {/* MESSAGE HISTORY */}
        <div className="card">
          <div className="card-header" style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <h3 className="card-title">Message History</h3>
            <span className="badge">{messages.length} total</span>
          </div>
          
          {loading ? (
            <div style={{ padding: "40px", textAlign: "center" }}>
              <div className="spinner"></div>
            </div>
          ) : messages.length === 0 ? (
            <div className="empty-state">
              <div className="empty-state-icon"><LuMail /></div>
              <div className="empty-state-title">No messages sent</div>
              <div className="empty-state-text">
                Operational communications will appear here.
              </div>
            </div>
          ) : (
            <div style={{ display: "flex", flexDirection: "column" }}>
              {messages.map(msg => (
                <div key={msg.id} style={{ padding: "16px", borderBottom: "1px solid var(--border-default)" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "8px" }}>
                    <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                      <div style={{ 
                        display: "flex", alignItems: "center", justifyContent: "center",
                        width: "32px", height: "32px", borderRadius: "8px",
                        backgroundColor: "var(--bg-secondary)", color: getPriorityColor(msg.priority)
                      }}>
                        {getTargetIcon(msg.target_type)}
                      </div>
                      <div>
                        <div style={{ fontWeight: "600", fontSize: "0.9rem" }}>
                          To: {msg.target_type.toUpperCase()} {msg.target_id ? `(${msg.target_id})` : ""}
                        </div>
                        <div style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>
                          From: {msg.sender_name} &middot; {new Date(msg.created_at).toLocaleString()}
                        </div>
                      </div>
                    </div>
                    {msg.requires_acknowledgment && (
                      <div className="badge warning" style={{ display: "flex", alignItems: "center", gap: "4px" }}>
                        <LuCheckCheck size={12} /> Requires Ack
                      </div>
                    )}
                  </div>
                  <div style={{ backgroundColor: "var(--bg-secondary)", padding: "12px", borderRadius: "8px", fontSize: "0.9rem", lineHeight: "1.5" }}>
                    {msg.content}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
