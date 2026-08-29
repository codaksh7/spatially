import { useState, useEffect } from "react";
import { api } from "../utils/api";
import { useToast } from "./Toast";
import { LuMapPin, LuCircleCheck, LuCircleAlert, LuGripVertical, LuTrash2 } from "react-icons/lu";

export default function VolunteerPlacer({ eventId, onSelectVolunteer, selectedVolunteer, refreshTrigger, onRefresh }) {
  const toast = useToast();
  const [volunteers, setVolunteers] = useState([]);
  const [positions, setPositions] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchData() {
      try {
        const [volRes, posRes] = await Promise.all([
          api.get(`/api/volunteers/event/${eventId}/assignments`),
          api.get(`/api/venue-map/${eventId}/volunteers`),
        ]);
        setVolunteers(volRes.volunteers || []);
        setPositions(posRes.positions || []);
      } catch (err) {
        toast(err.message, "error");
      } finally {
        setLoading(false);
      }
    }
    fetchData();
  }, [eventId, refreshTrigger]);

  const placedIds = new Set(positions.map((p) => p.volunteer_user_id));
  const placedVols = volunteers.filter((v) => placedIds.has(v.user_id));
  const unplacedVols = volunteers.filter((v) => !placedIds.has(v.user_id));

  const getPosition = (userId) => positions.find((p) => p.volunteer_user_id === userId);

  const handleRemove = async (e, userId) => {
    e.stopPropagation();
    if (!window.confirm(`Are you sure you want to remove ${userId} from the map?`)) return;
    try {
      await api.delete(`/api/venue-map/${eventId}/remove-position/${userId}`);
      toast(`${userId} removed from map`, "success");
      onSelectVolunteer(null);
      if (onRefresh) onRefresh();
    } catch (err) {
      toast(err.message, "error");
    }
  };

  if (loading) {
    return (
      <div className="volunteer-placer">
        <div className="volunteer-placer-header">
          <h4>Volunteer Placement</h4>
        </div>
        <div style={{ padding: "20px", textAlign: "center" }}>
          <div className="spinner spinner-sm"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="volunteer-placer">
      <div className="volunteer-placer-header">
        <h4>Volunteer Placement</h4>
        <span className="badge badge-upcoming">{volunteers.length} total</span>
      </div>

      {selectedVolunteer && (
        <div className="volunteer-placer-hint">
          <LuCircleAlert size={14} />
          Click a zone on the map to place <strong>{selectedVolunteer}</strong>
        </div>
      )}

      {/* Unplaced section */}
      {unplacedVols.length > 0 && (
        <div className="volunteer-placer-section">
          <div className="volunteer-placer-section-label">Unplaced ({unplacedVols.length})</div>
          {unplacedVols.map((v) => (
            <div
              key={v.user_id}
              className={`volunteer-placer-item ${selectedVolunteer === v.user_id ? "selected" : ""}`}
              onClick={() => onSelectVolunteer(selectedVolunteer === v.user_id ? null : v.user_id)}
            >
              <div className="volunteer-placer-item-info">
                <LuGripVertical size={14} className="volunteer-placer-grip" />
                <div className="volunteer-placer-dot unplaced"></div>
                <div>
                  <div className="volunteer-placer-name">{v.full_name || v.user_id}</div>
                  <div className="volunteer-placer-id">{v.user_id}</div>
                </div>
              </div>
              <button
                className="btn btn-sm btn-secondary"
                onClick={(e) => {
                  e.stopPropagation();
                  onSelectVolunteer(v.user_id);
                }}
              >
                Place
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Placed section */}
      {placedVols.length > 0 && (
        <div className="volunteer-placer-section">
          <div className="volunteer-placer-section-label">
            <LuCircleCheck size={13} /> Placed ({placedVols.length})
          </div>
          {placedVols.map((v) => {
            const pos = getPosition(v.user_id);
            return (
              <div
                key={v.user_id}
                className={`volunteer-placer-item placed ${selectedVolunteer === v.user_id ? "selected" : ""}`}
                onClick={() => onSelectVolunteer(selectedVolunteer === v.user_id ? null : v.user_id)}
              >
                <div className="volunteer-placer-item-info">
                  <div className="volunteer-placer-dot placed"></div>
                  <div>
                    <div className="volunteer-placer-name">{v.full_name || v.user_id}</div>
                    <div className="volunteer-placer-id">
                      {v.user_id} • Zone {pos?.zone}
                    </div>
                  </div>
                </div>
                <div style={{ display: "flex", gap: "8px" }}>
                  <button
                    className="btn btn-sm btn-ghost"
                    onClick={(e) => {
                      e.stopPropagation();
                      onSelectVolunteer(v.user_id);
                    }}
                  >
                    <LuMapPin size={12} /> Relocate
                  </button>
                  <button
                    className="btn btn-sm btn-ghost"
                    style={{ color: "var(--error)", padding: "4px 8px" }}
                    onClick={(e) => handleRemove(e, v.user_id)}
                  >
                    <LuTrash2 size={12} />
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {volunteers.length === 0 && (
        <div style={{ padding: "24px 16px", textAlign: "center", color: "var(--text-muted)", fontSize: "0.85rem" }}>
          No volunteers assigned to this event yet.
        </div>
      )}
    </div>
  );
}
