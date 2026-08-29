import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { formatDate, getStatusColor } from "../utils/validators";
import { LuMapPin, LuClock, LuRadar, LuCalendarDays, LuMap } from "react-icons/lu";

export default function VolunteerAssignments() {
  const toast = useToast();
  const navigate = useNavigate();
  const [data, setData] = useState({ events: [], assignments: [] });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get("/api/events/volunteer/assigned")
      .then(setData)
      .catch((err) => toast(err.message, "error"))
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return <div className="loading-screen" style={{ minHeight: "60vh" }}><div className="spinner"></div></div>;
  }

  return (
    <div className="fade-in">
      <div className="page-header">
        <h1>My Assignments</h1>
      </div>

      {data.events?.length > 0 ? (
        <div className="events-grid">
          {data.events.map((event) => {
            const assignment = data.assignments?.find((a) => a.event_id === event.id);
            return (
              <div key={event.id} className="event-card">
                <div className="event-card-header">
                  <div className="event-card-title">{event.name}</div>
                  <span className={`badge ${getStatusColor(event.status)}`}>{event.status}</span>
                </div>
                <div className="event-card-meta">
                  <div className="event-card-meta-item"><LuMapPin className="meta-icon" size={14} />{event.venue}</div>
                  <div className="event-card-meta-item"><LuClock className="meta-icon" size={14} />{formatDate(event.event_date)}</div>
                </div>
                {assignment?.zone && (
                  <div style={{ marginTop: "10px" }}>
                    <span className="badge badge-live"><LuRadar size={12} style={{ marginRight: "4px" }} />Zone: {assignment.zone}</span>
                  </div>
                )}
                {event.zones?.length > 0 && (
                  <div className="event-card-zones" style={{ marginTop: "10px" }}>
                    {event.zones.map((z) => <span key={z} className="zone-tag">{z}</span>)}
                  </div>
                )}
                <div className="event-card-footer">
                  <button
                    className="btn btn-sm btn-secondary"
                    onClick={() => navigate(`/volunteer/event-map/${event.id}`)}
                  >
                    <LuMap size={14} /> View Map
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        <div className="empty-state">
          <div className="empty-state-icon"><LuCalendarDays /></div>
          <div className="empty-state-title">No assignments yet</div>
          <div className="empty-state-text">You will see event assignments here when an organizer assigns you.</div>
        </div>
      )}
    </div>
  );
}

