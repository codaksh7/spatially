import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../utils/api";
import { formatDate, formatTime } from "../utils/validators";
import { LuActivity, LuMapPin, LuUsers, LuArrowLeftRight, LuCircleCheck, LuArrowRight } from "react-icons/lu";

export default function EventLogsPanel({ eventId, refreshTrigger }) {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    async function fetchLogs() {
      try {
        const res = await api.get(`/api/logs/${eventId}?limit=5`);
        setLogs(res.logs || []);
      } catch (err) {
        console.error("Failed to fetch logs", err);
      } finally {
        setLoading(false);
      }
    }
    fetchLogs();
  }, [eventId, refreshTrigger]);

  const getLogIcon = (type) => {
    switch (type) {
      case "placement":
      case "move":
        return <LuMapPin size={14} className="log-icon placement" />;
      case "switch":
        return <LuArrowLeftRight size={14} className="log-icon switch" />;
      case "invite":
        return <LuUsers size={14} className="log-icon invite" />;
      case "assignment":
        return <LuCircleCheck size={14} className="log-icon assignment" />;
      default:
        return <LuActivity size={14} className="log-icon default" />;
    }
  };

  if (loading) {
    return (
      <div className="event-logs-panel loading">
        <div className="spinner spinner-sm"></div>
      </div>
    );
  }

  return (
    <div className="event-logs-panel">
      <div className="event-logs-header">
        <h4>Recent Activity</h4>
      </div>

      {logs.length === 0 ? (
        <div className="event-logs-empty">
          <LuActivity size={24} style={{ opacity: 0.5, marginBottom: "8px" }} />
          <p>No activity recorded yet.</p>
        </div>
      ) : (
        <div className="event-logs-list">
          {logs.map((log) => (
            <div key={log.id} className="event-log-item">
              <div className="event-log-icon-wrap">
                {getLogIcon(log.action_type)}
              </div>
              <div className="event-log-content">
                <div className="event-log-desc">{log.description}</div>
                <div className="event-log-meta">
                  {formatDate(log.created_at)} at {formatTime(log.created_at)}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      <button
        className="btn btn-ghost w-full event-logs-view-all"
        onClick={() => navigate(`/organizer/event-logs/${eventId}`)}
      >
        View All Logs <LuArrowRight size={14} />
      </button>
    </div>
  );
}
