import { useState, useEffect, useRef, useCallback } from "react";
import { api } from "../utils/api";
import { LuRadar, LuUsers, LuSave, LuX } from "react-icons/lu";

const DENSITY_COLORS = [
  { min: 0, max: 99, color: "#C9B800", label: "Low (0–99)" },
  { min: 100, max: 499, color: "#2D8B46", label: "Moderate (100–499)" },
  { min: 500, max: 999, color: "#D4710E", label: "High (500–999)" },
  { min: 1000, max: Infinity, color: "#C03030", label: "Critical (1000+)" },
];

const VOLUNTEER_COLOR = "#0077B6"; 
const VOLUNTEER_SELF_COLOR = "#00B4D8";

function getDensityColor(count) {
  for (const tier of DENSITY_COLORS) {
    if (count >= tier.min && count <= tier.max) return tier;
  }
  return DENSITY_COLORS[0];
}


// Standard Polar to Cartesian
function polarToCartesian(centerX, centerY, radiusX, radiusY, angleInDegrees) {
  const angleInRadians = (angleInDegrees - 90) * Math.PI / 180.0;
  return {
    x: centerX + (radiusX * Math.cos(angleInRadians)),
    y: centerY + (radiusY * Math.sin(angleInRadians))
  };
}

function computeAutoZoneLayout(zones) {
  const n = zones.length;
  if (n === 0) return [];
  
  // Ellipse radii for initial placement (middle of cyan seating area)
  // These are relative to 1x1 to yield percentages
  const rx = 0.39; 
  const ry = 0.385;
  
  const angleStep = 360 / n;
  const startOffset = 180;

  return zones.map((z, i) => {
    const angle = (startOffset + (i * angleStep)) % 360;
    const pos = polarToCartesian(0.5, 0.5, rx, ry, angle);
    return {
      zone: z,
      x: pos.x,
      y: pos.y
    };
  });
}

function getClosestZoneInfo(x, y, zoneLayout, containerW, containerH) {
  if (!zoneLayout || zoneLayout.length === 0) return { zone: "Unknown", isNear: true };
  
  let closestZone = zoneLayout[0].zone;
  let minDist = Infinity;
  
  for (const z of zoneLayout) {
    const zx = z.x * containerW;
    const zy = z.y * containerH;
    const dx = x - zx;
    const dy = y - zy;
    const dist = Math.sqrt(dx*dx + dy*dy);
    
    if (dist < minDist) {
      minDist = dist;
      closestZone = z.zone;
    }
  }
  
  const isNear = minDist > 80;
  return { zone: closestZone, isNear };
}

export default function VenueMap({
  eventId,
  zones = [],
  mode = "viewer", 
  currentUserId = null,
  onZoneClick = null,
  selectedVolunteer = null,
  refreshTrigger = 0,
  onExitEditMode = null,
}) {
  const containerRef = useRef(null);
  const [density, setDensity] = useState({});
  const [volPositions, setVolPositions] = useState([]);
  const [containerSize, setContainerSize] = useState({ w: 800, h: 500 });
  const [hoveredZone, setHoveredZone] = useState(null);
  const [hoveredVolunteer, setHoveredVolunteer] = useState(null);
  const [loading, setLoading] = useState(true);

  const [serverLayout, setServerLayout] = useState(null);
  const [editLayout, setEditLayout] = useState(null);

  const [draggedVol, setDraggedVol] = useState(null);
  const [previewPos, setPreviewPos] = useState(null);

  const [draggedZone, setDraggedZone] = useState(null);

  const fetchData = useCallback(async () => {
    if (mode === "create-event") {
      setLoading(false);
      return;
    }
    try {
      const [densRes, volRes, layoutRes] = await Promise.all([
        api.get(`/api/venue-map/${eventId}/density`),
        api.get(`/api/venue-map/${eventId}/volunteers`),
        api.get(`/api/venue-map/${eventId}/layout`).catch(() => ({ layout: null })),
      ]);
      setDensity(densRes.density || {});
      setVolPositions(volRes.positions || []);
      if (layoutRes && layoutRes.layout && layoutRes.layout.length > 0) {
        setServerLayout(layoutRes.layout);
      }
    } catch {
      // Silently fail
    } finally {
      setLoading(false);
    }
  }, [eventId, mode]);

  useEffect(() => {
    fetchData();
  }, [fetchData, refreshTrigger]);

  useEffect(() => {
    const interval = setInterval(fetchData, 10000);
    return () => clearInterval(interval);
  }, [fetchData]);

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const observer = new ResizeObserver((entries) => {
      for (const entry of entries) {
        const { width } = entry.contentRect;
        setContainerSize({ w: width, h: Math.max(320, width * 0.55) });
      }
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if ((mode === "edit-zones" || mode === "create-event" || mode === "organizer") && !editLayout) {
      setEditLayout(serverLayout || computeAutoZoneLayout(zones));
    } else if (mode !== "edit-zones" && mode !== "create-event" && mode !== "organizer") {
      setEditLayout(null);
    }
  }, [mode, serverLayout, zones, editLayout]);

  const activeLayout = (mode === "edit-zones" || mode === "create-event" || mode === "organizer") ? editLayout : (serverLayout || computeAutoZoneLayout(zones));

  const handleSaveLayout = async () => {
    if (mode === "create-event" && onExitEditMode) {
      onExitEditMode(editLayout);
      return;
    }
    try {
      await api.post(`/api/venue-map/${eventId}/layout`, { layout: editLayout });
      setServerLayout(editLayout);
      if (onExitEditMode) onExitEditMode();
    } catch (err) {
      alert("Failed to save layout");
    }
  };

  const handleMapClick = (e) => {
    if (mode !== "organizer" || !onZoneClick || draggedVol) return;
    const rect = e.currentTarget.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const relX = (x / rect.width) * 100;
    const relY = (y / rect.height) * 100;
    
    const { zone: closestZone } = getClosestZoneInfo(x, y, activeLayout || [], rect.width, rect.height);

    if (selectedVolunteer) {
      setVolPositions(prev => {
        const exists = prev.find(v => v.volunteer_user_id === selectedVolunteer);
        if (exists) {
          return prev.map(v => v.volunteer_user_id === selectedVolunteer ? { ...v, pos_x: relX, pos_y: relY, zone: closestZone } : v);
        }
        return [...prev, { volunteer_user_id: selectedVolunteer, pos_x: relX, pos_y: relY, zone: closestZone }];
      });
    }
    onZoneClick(closestZone, relX, relY);
  };

  const handlePointerDownVol = (e, volId, origX, origY) => {
    if (mode !== "organizer" || !onZoneClick) return;
    e.stopPropagation();
    setDraggedVol(volId);
    setPreviewPos({ x: origX, y: origY });
    e.target.setPointerCapture(e.pointerId);
  };

  const handlePointerUpVol = (e) => {
    if (!draggedVol) return;
    const finalVol = draggedVol;
    const finalPos = previewPos;
    
    setDraggedVol(null);
    setPreviewPos(null);
    e.target.releasePointerCapture(e.pointerId);

    if (onZoneClick && finalPos) {
      const rect = e.currentTarget.getBoundingClientRect();
      const x = (finalPos.x / 100) * rect.width;
      const y = (finalPos.y / 100) * rect.height;
      const { zone: closestZone } = getClosestZoneInfo(x, y, activeLayout || [], rect.width, rect.height);

      setVolPositions(prev => {
        const exists = prev.find(v => v.volunteer_user_id === finalVol);
        if (exists) {
          return prev.map(v => v.volunteer_user_id === finalVol ? { ...v, pos_x: finalPos.x, pos_y: finalPos.y, zone: closestZone } : v);
        }
        return [...prev, { volunteer_user_id: finalVol, pos_x: finalPos.x, pos_y: finalPos.y, zone: closestZone }];
      });
      onZoneClick(closestZone, finalPos.x, finalPos.y, finalVol);
    }
  };

  const handlePointerDownZone = (e, index) => {
    if (mode !== "edit-zones" && mode !== "create-event" && mode !== "organizer") return;
    e.stopPropagation();
    setDraggedZone({ index });
    e.target.setPointerCapture(e.pointerId);
  };

  const handlePointerMove = (e) => {
    if (draggedVol) {
      const rect = e.currentTarget.getBoundingClientRect();
      let x = e.clientX - rect.left;
      let y = e.clientY - rect.top;
      x = Math.max(0, Math.min(x, rect.width));
      y = Math.max(0, Math.min(y, rect.height));
      setPreviewPos({ x: (x / rect.width) * 100, y: (y / rect.height) * 100 });
      return;
    }

    if (draggedZone && editLayout) {
      const rect = e.currentTarget.getBoundingClientRect();
      let x = e.clientX - rect.left;
      let y = e.clientY - rect.top;
      
      x = Math.max(0, Math.min(x, rect.width));
      y = Math.max(0, Math.min(y, rect.height));
      
      const relX = x / rect.width;
      const relY = y / rect.height;
      
      const { index } = draggedZone;
      setEditLayout(prev => {
        const next = [...prev];
        next[index] = { ...next[index], x: relX, y: relY };
        return next;
      });
    }
  };

  const handlePointerUp = (e) => {
    if (draggedVol) handlePointerUpVol(e);
    if (draggedZone) {
      setDraggedZone(null);
      e.target.releasePointerCapture(e.pointerId);
      if (mode === "organizer") {
        handleSaveLayout();
      }
    }
  };

  if (zones.length === 0) {
    return (
      <div className="venue-map-empty">
        <LuRadar size={32} />
        <p>No zones configured for this event. Add zones to enable the venue map.</p>
      </div>
    );
  }

  const safeLayout = activeLayout || [];

  return (
    <div className="venue-map-wrapper">
      
      {(mode === "edit-zones" || mode === "create-event") && (
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", background: "var(--bg-tertiary)", padding: "10px 16px", borderRadius: "8px", border: "1px solid var(--border-light)" }}>
          <div style={{ fontSize: "0.85rem" }}>
            <strong>Edit Zones Mode:</strong> Drag and drop the zone boxes to custom locations.
          </div>
          <div style={{ display: "flex", gap: "8px" }}>
            {mode === "edit-zones" && <button className="btn btn-sm btn-ghost" onClick={onExitEditMode}><LuX size={14}/> Cancel</button>}
            <button className="btn btn-sm btn-primary" onClick={handleSaveLayout}><LuSave size={14}/> {mode === "create-event" ? "Save & Create Event" : "Save Layout"}</button>
          </div>
        </div>
      )}

      <div className="venue-map-container" ref={containerRef} style={{ borderRadius: "12px", overflow: "hidden" }}>
        {loading && (
          <div className="venue-map-loading">
            <div className="spinner"></div>
          </div>
        )}

        <svg
          width={containerSize.w}
          height={containerSize.h}
          viewBox={`0 0 ${containerSize.w} ${containerSize.h}`}
          preserveAspectRatio="none"
          className="venue-map-svg"
          style={{ cursor: mode === "organizer" && !draggedVol ? "crosshair" : "default", touchAction: "none" }}
          onClick={handleMapClick}
          onPointerMove={handlePointerMove}
          onPointerUp={handlePointerUp}
          onPointerLeave={handlePointerUp}
        >
          <image
            href="/images/stadium_map_bg.png"
            x="0"
            y="0"
            width={containerSize.w}
            height={containerSize.h}
            preserveAspectRatio="none"
            opacity="0.6"
          />

          {safeLayout.map((zl, i) => {
            const count = density[zl.zone] || 0;
            const tier = getDensityColor(count);
            const isHovered = hoveredZone === zl.zone;
            const isEdit = (mode === "edit-zones" || mode === "create-event" || mode === "organizer");

            const posX = zl.x * containerSize.w;
            const posY = zl.y * containerSize.h;
            
            const boxW = 80;
            const boxH = 46;

            let fillStyle = "rgba(0, 0, 0, 0.6)";
            let strokeStyle = "rgba(255,255,255,0.2)";
            
            if (isEdit) {
              fillStyle = "rgba(0, 180, 216, 0.3)";
              strokeStyle = "#00B4D8";
            } else if (isHovered && !draggedVol) {
              fillStyle = "rgba(0, 180, 216, 0.5)";
              strokeStyle = "#00B4D8";
            }

            return (
              <g 
                key={zl.zone} 
                transform={`translate(${posX}, ${posY})`}
                style={{ cursor: isEdit ? (draggedZone ? "grabbing" : "grab") : (isHovered && !draggedVol ? "pointer" : "default") }}
                onPointerDown={(e) => {
                  if (isEdit) handlePointerDownZone(e, i);
                }}
                onMouseEnter={() => setHoveredZone(zl.zone)}
                onMouseLeave={() => setHoveredZone(null)}
              >
                <rect
                  x={-boxW/2}
                  y={-boxH/2}
                  width={boxW}
                  height={boxH}
                  rx={8}
                  fill={fillStyle}
                  stroke={strokeStyle}
                  strokeWidth={isEdit || isHovered ? 2 : 1}
                  style={{ backdropFilter: "blur(4px)", transition: "fill 0.2s" }}
                />
                
                <text
                  y={isEdit ? 5 : -4}
                  textAnchor="middle"
                  fill="#fff"
                  fontSize="13"
                  fontWeight="700"
                  fontFamily="Inter, sans-serif"
                  pointerEvents="none"
                  style={{ textShadow: "0 1px 3px rgba(0,0,0,0.8)" }}
                >
                  {zl.zone}
                </text>
                
                {!isEdit && (
                   <text
                     y={12}
                     textAnchor="middle"
                     fill={tier.color}
                     fontSize="11"
                     fontWeight="600"
                     fontFamily="Inter, sans-serif"
                     pointerEvents="none"
                     style={{ textShadow: "0 1px 3px rgba(0,0,0,0.8)" }}
                   >
                     {count} people
                   </text>
                )}
              </g>
            );
          })}

          {/* Volunteer dots */}
          {volPositions.map((v) => {
            const isDragged = draggedVol === v.volunteer_user_id;
            const posX = isDragged && previewPos ? previewPos.x : v.pos_x;
            const posY = isDragged && previewPos ? previewPos.y : v.pos_y;
            
            const dotX = (posX / 100) * containerSize.w;
            const dotY = (posY / 100) * containerSize.h;
            
            const isSelf = v.volunteer_user_id === currentUserId;
            const isSelected = v.volunteer_user_id === selectedVolunteer;
            const isHovered = hoveredVolunteer === v.volunteer_user_id || isDragged;
            const dotR = isSelf ? 7.5 : 6; 

            const { zone: clZone, isNear } = getClosestZoneInfo(dotX, dotY, safeLayout, containerSize.w, containerSize.h);
            const labelStr = isNear ? `Near ${clZone}` : clZone;

            return (
              <g 
                key={v.volunteer_user_id} 
                onMouseEnter={() => setHoveredVolunteer(v.volunteer_user_id)}
                onMouseLeave={() => setHoveredVolunteer(null)}
                style={{ cursor: mode === "organizer" ? (isDragged ? "grabbing" : "grab") : "pointer" }}
              >
                {(isHovered || isSelected) && (
                  <circle
                    cx={dotX}
                    cy={dotY}
                    r={60}
                    fill="rgba(0, 180, 216, 0.15)"
                    stroke="rgba(0, 180, 216, 0.6)"
                    strokeWidth="1.5"
                    strokeDasharray="4 4"
                    className="ble-radius-pulse"
                    pointerEvents="none"
                  />
                )}
                
                {isSelected && !isDragged && (
                  <circle
                    cx={dotX}
                    cy={dotY}
                    r={11}
                    fill="none"
                    stroke="#fff"
                    strokeWidth="2"
                    strokeDasharray="3 2"
                    pointerEvents="none"
                  />
                )}
                
                <circle
                  cx={dotX}
                  cy={dotY}
                  r={isDragged ? dotR * 1.5 : dotR}
                  fill={isSelf ? VOLUNTEER_SELF_COLOR : VOLUNTEER_COLOR}
                  stroke="#fff"
                  strokeWidth="1.5"
                  onPointerDown={(e) => handlePointerDownVol(e, v.volunteer_user_id, posX, posY)}
                />
                
                <text
                  x={dotX}
                  y={dotY - (isDragged ? dotR * 1.5 : dotR) - 6}
                  textAnchor="middle"
                  fill="#fff"
                  fontSize="11"
                  fontWeight="800"
                  fontFamily="Inter, sans-serif"
                  pointerEvents="none"
                  style={{ textShadow: "0 2px 4px rgba(0,0,0,0.8)" }}
                >
                  {v.volunteer_user_id}
                </text>
                
                <text
                  x={dotX}
                  y={dotY + (isDragged ? dotR * 1.5 : dotR) + 12}
                  textAnchor="middle"
                  fill="rgba(255,255,255,0.7)"
                  fontSize="9"
                  fontWeight="600"
                  fontFamily="Inter, sans-serif"
                  pointerEvents="none"
                  style={{ textShadow: "0 1px 2px rgba(0,0,0,0.8)" }}
                >
                  {labelStr}
                </text>
              </g>
            );
          })}
        </svg>
      </div>

      <div className="venue-map-legend">
        <div className="venue-map-legend-title">
          <LuUsers size={14} /> Crowd Density
        </div>
        <div className="venue-map-legend-items">
          {DENSITY_COLORS.map((tier) => (
            <div key={tier.label} className="venue-map-legend-item">
              <span className="venue-map-legend-swatch" style={{ backgroundColor: tier.color }}></span>
              <span>{tier.label}</span>
            </div>
          ))}
          <div className="venue-map-legend-item">
            <span className="venue-map-legend-swatch venue-map-legend-swatch-vol" style={{ backgroundColor: VOLUNTEER_COLOR }}></span>
            <span>Volunteer</span>
          </div>
        </div>
      </div>
    </div>
  );
}
