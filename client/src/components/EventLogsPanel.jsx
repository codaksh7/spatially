import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../utils/api";
import { formatDate, formatTime } from "../utils/validators";
import { LuActivity, LuMapPin, LuUsers, LuArrowLeftRight, LuCircleCheck, LuArrowRight, LuTriangleAlert, LuMessageSquare, LuSquareCheck } from "react-icons/lu";
import { supabase } from "../utils/supabaseClient";

export default function EventLogsPanel({ eventId, refreshTrigger }) {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    async function fetchLogs() {
      try {
        const { data, error } = await supabase.rpc('get_event_operational_timeline', { 
          p_event_id: eventId,
          p_limit: 10
        });
        if (error) throw error;
        setLogs(data || []);
      } catch (err) {
        console.error("Failed to fetch operational timeline", err);
      } finally {
        setLoading(false);
      }
    }
    fetchLogs();

    const channel = supabase.channel(`timeline_${eventId}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'operational_incidents', filter: `event_id=eq.${eventId}` }, fetchLogs)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'shift_handoffs', filter: `event_id=eq.${eventId}` }, fetchLogs)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'supervisor_tasks', filter: `event_id=eq.${eventId}` }, fetchLogs)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'coverage_requests', filter: `event_id=eq.${eventId}` }, fetchLogs)
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [eventId, refreshTrigger]);

  const getLogIcon = (type) => {
    switch (type) {
      case "incident": return <LuTriangleAlert size={14} className="log-icon warning" />;
      case "message": return <LuMessageSquare size={14} className="log-icon info" />;
      case "task": return <LuSquareCheck size={14} className="log-icon success" />;
      case "coverage": return <LuUsers size={14} className="log-icon placement" />;
      case "handoff": return <LuArrowLeftRight size={14} className="log-icon switch" />;
      default: return <LuActivity size={14} className="log-icon default" />;
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
                {getLogIcon(log.source_type || log.action_type)}
              </div>
              <div className="event-log-content">
                <div className="event-log-desc">
                  <strong>{log.title || log.event_type}</strong> - {log.description}
                  {log.zone_name && <span className="zone-tag" style={{ marginLeft: "6px" }}>{log.zone_name}</span>}
                </div>
                <div className="event-log-meta">
                  {log.actor_name && <span>By {log.actor_name} &bull; </span>}
                  {formatDate(log.timestamp || log.created_at)} at {formatTime(log.timestamp || log.created_at)}
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
