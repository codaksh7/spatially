import { useState, useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { api } from "../utils/api";
import { useToast } from "../components/Toast";
import { formatDate, formatTime } from "../utils/validators";
import { 
  LuArrowLeft, 
  LuActivity, 
  LuMapPin, 
  LuUsers, 
  LuArrowLeftRight, 
  LuCircleCheck 
} from "react-icons/lu";

export default function EventLogs() {
  const { eventId } = useParams();
  const navigate = useNavigate();
  const toast = useToast();
  
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [event, setEvent] = useState(null);

  useEffect(() => {
    async function fetchData() {
      try {
        const [eventRes, logsRes] = await Promise.all([
          api.get(`/api/events/${eventId}`),
          api.get(`/api/logs/${eventId}?limit=200`) // Fetch up to 200 logs for history
        ]);
        setEvent(eventRes);
        setLogs(logsRes.logs || []);
      } catch (err) {
        if (!err.message.includes("fetch")) {
            toast(err.message, "error");
        }
      } finally {
        setLoading(false);
      }
    }
    fetchData();
  }, [eventId]);

  const getLogIcon = (type) => {
    switch (type) {
      case "placement":
      case "move":
        return <LuMapPin size={18} className="log-icon placement" />;
      case "switch":
        return <LuArrowLeftRight size={18} className="log-icon switch" />;
      case "invite":
        return <LuUsers size={18} className="log-icon invite" />;
      case "assignment":
        return <LuCircleCheck size={18} className="log-icon assignment" />;
      default:
        return <LuActivity size={18} className="log-icon default" />;
    }
  };

  if (loading) {
    return (
      <div className="loading-screen" style={{ minHeight: "70vh" }}>
        <div className="spinner"></div>
      </div>
    );
  }

  return (
    <div className="fade-in">
      <div className="page-header" style={{ display: "flex", gap: "16px", alignItems: "center" }}>
        <button 
          className="btn btn-icon btn-ghost" 
          onClick={() => navigate(`/organizer/events/${eventId}`)}
          title="Back to Event"
        >
          <LuArrowLeft />
        </button>
        <div>
          <h1 style={{ display: "flex", alignItems: "center", gap: "10px", margin: 0 }}>
            <LuActivity /> Activity Logs
          </h1>
          {event && (
            <div style={{ fontSize: "0.9rem", color: "var(--text-muted)", marginTop: "4px" }}>
              {event.name}
            </div>
          )}
        </div>
      </div>

      <div className="card full-logs-card">
        {logs.length === 0 ? (
          <div className="empty-state">
            <div className="empty-state-icon"><LuActivity /></div>
            <div className="empty-state-title">No Activity Yet</div>
            <div className="empty-state-text">Actions like inviting volunteers or placing them on the map will appear here.</div>
          </div>
        ) : (
          <div className="full-logs-list">
            {logs.map((log) => (
              <div key={log.id} className="full-log-item">
                <div className="full-log-icon">
                  {getLogIcon(log.action_type)}
                </div>
                <div className="full-log-content">
                  <div className="full-log-header">
                    <span className={`log-badge badge-${log.action_type}`}>
                      {log.action_type.toUpperCase()}
                    </span>
                    <span className="full-log-time">
                      {formatDate(log.created_at)} • {formatTime(log.created_at)}
                    </span>
                  </div>
                  <div className="full-log-desc">{log.description}</div>
                  <div className="full-log-actor">Actor ID: {log.actor_id}</div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
