import { useEffect, useState } from "react";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { LuSquareCheck, LuPlus, LuMapPin, LuUser, LuClock } from "react-icons/lu";
import { Link } from "react-router-dom";

export default function OrganizerTasks() {
  const { user } = useAuth();
  const toast = useToast();
  const [events, setEvents] = useState([]);
  const [selectedEventId, setSelectedEventId] = useState("");
  const [tasks, setTasks] = useState([]);
  const [loading, setLoading] = useState(true);

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
    setLoading(true);
    
    api.get(`/api/organizer/tasks/${selectedEventId}`)
      .then((data) => setTasks(data.tasks || []))
      .catch((err) => toast(err.message, "error"))
      .finally(() => setLoading(false));
  }, [selectedEventId]);

  const getPriorityColor = (priority) => {
    switch(priority) {
      case "urgent": return "var(--error)";
      case "high": return "var(--warning)";
      default: return "var(--info)";
    }
  };

  // Group tasks by status for Kanban view
  const pendingTasks = tasks.filter(t => t.status === "pending" || t.status === "assigned");
  const inProgressTasks = tasks.filter(t => t.status === "in_progress" || t.status === "acknowledged");
  const completedTasks = tasks.filter(t => t.status === "completed" || t.status === "cancelled");

  const TaskCard = ({ task }) => (
    <div className="card" style={{ marginBottom: "12px", padding: "16px", cursor: "pointer" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "8px" }}>
        <div style={{ display: "flex", gap: "8px", alignItems: "center" }}>
          <div style={{ width: "8px", height: "8px", borderRadius: "50%", backgroundColor: getPriorityColor(task.priority) }} />
          <div style={{ fontWeight: "600", fontSize: "0.95rem" }}>{task.title}</div>
        </div>
      </div>
      
      {task.description && (
        <div style={{ fontSize: "0.85rem", color: "var(--text-secondary)", marginBottom: "12px", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical", overflow: "hidden" }}>
          {task.description}
        </div>
      )}
      
      <div style={{ display: "flex", flexDirection: "column", gap: "6px", fontSize: "0.8rem", color: "var(--text-muted)" }}>
        {task.zone_name && (
          <div style={{ display: "flex", alignItems: "center", gap: "4px" }}>
            <LuMapPin size={12} /> {task.zone_name}
          </div>
        )}
        {task.assigned_to ? (
          <div style={{ display: "flex", alignItems: "center", gap: "4px" }}>
            <LuUser size={12} /> {task.assigned_to.substring(0, 8)}...
          </div>
        ) : (
          <div style={{ display: "flex", alignItems: "center", gap: "4px", color: "var(--warning)" }}>
            <LuUser size={12} /> Unassigned
          </div>
        )}
        <div style={{ display: "flex", alignItems: "center", gap: "4px" }}>
          <LuClock size={12} /> {new Date(task.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
        </div>
      </div>
    </div>
  );

  return (
    <div className="fade-in">
      <div className="page-header">
        <div>
          <h1>Task Delegator</h1>
          <p style={{ color: "var(--text-muted)", marginTop: "4px" }}>
            Dispatch and monitor ad-hoc operational tasks across the venue.
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
          <button className="btn btn-primary">
            <LuPlus size={16} /> New Task
          </button>
        </div>
      </div>

      {loading ? (
        <div style={{ padding: "40px", textAlign: "center" }}>
          <div className="spinner"></div>
        </div>
      ) : tasks.length === 0 ? (
        <div className="empty-state">
          <div className="empty-state-icon"><LuSquareCheck /></div>
          <div className="empty-state-title">No tasks found</div>
          <div className="empty-state-text">
            There are no operational tasks for this event.
          </div>
          <button className="btn btn-primary" style={{ marginTop: "16px" }}>
            <LuPlus size={16} /> Create Task
          </button>
        </div>
      ) : (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: "20px" }}>
          
          {/* TO DO COLUMN */}
          <div style={{ backgroundColor: "var(--bg-elevated)", borderRadius: "12px", padding: "16px", minHeight: "500px", border: "1px solid var(--border-default)" }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "16px" }}>
              <h3 style={{ fontSize: "1rem", fontWeight: "600", display: "flex", alignItems: "center", gap: "8px" }}>
                <div style={{ width: "10px", height: "10px", borderRadius: "50%", backgroundColor: "var(--text-muted)" }} />
                Pending
              </h3>
              <span className="badge">{pendingTasks.length}</span>
            </div>
            {pendingTasks.map(task => <TaskCard key={task.id} task={task} />)}
          </div>

          {/* IN PROGRESS COLUMN */}
          <div style={{ backgroundColor: "var(--bg-elevated)", borderRadius: "12px", padding: "16px", minHeight: "500px", border: "1px solid var(--border-default)" }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "16px" }}>
              <h3 style={{ fontSize: "1rem", fontWeight: "600", display: "flex", alignItems: "center", gap: "8px" }}>
                <div style={{ width: "10px", height: "10px", borderRadius: "50%", backgroundColor: "var(--info)" }} />
                In Progress
              </h3>
              <span className="badge">{inProgressTasks.length}</span>
            </div>
            {inProgressTasks.map(task => <TaskCard key={task.id} task={task} />)}
          </div>

          {/* COMPLETED COLUMN */}
          <div style={{ backgroundColor: "var(--bg-elevated)", borderRadius: "12px", padding: "16px", minHeight: "500px", border: "1px solid var(--border-default)" }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "16px" }}>
              <h3 style={{ fontSize: "1rem", fontWeight: "600", display: "flex", alignItems: "center", gap: "8px" }}>
                <div style={{ width: "10px", height: "10px", borderRadius: "50%", backgroundColor: "var(--success)" }} />
                Completed
              </h3>
              <span className="badge">{completedTasks.length}</span>
            </div>
            {completedTasks.map(task => <TaskCard key={task.id} task={task} />)}
          </div>

        </div>
      )}
    </div>
  );
}
