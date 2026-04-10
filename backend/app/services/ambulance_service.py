"""
Ambulance Service — VitalGuard
================================
Changes vs. v1:
  1. Hospital assignment is now LOAD-BALANCED — tracks active cases per
     hospital and routes new SOS to the hospital with fewest active cases.
     Breaks ties by geographic distance.
  2. Ambulance routing now follows real roads via the free OSRM routing API
     (router.project-osrm.org) instead of straight-line interpolation.
     Falls back to straight-line only if OSRM is unreachable.
"""

import asyncio, math, httpx
from typing import Dict, List, Optional
from datetime import datetime, timezone
from app.services.traffic_service import (
    request_green_corridor, update_ambulance_position, release_green_corridor)

_ambulances: Dict[str, dict] = {}

# ── Hospital Registry ─────────────────────────────────────────────
HOSPITALS = [
    {"name": "Apollo Hospital",     "lat": 12.9252, "lng": 77.6011},
    {"name": "Fortis Hospital",     "lat": 12.9611, "lng": 77.6387},
    {"name": "Manipal Hospital",    "lat": 12.9591, "lng": 77.6473},
    {"name": "Narayana Health",     "lat": 12.8938, "lng": 77.5949},
    {"name": "St. John's Hospital", "lat": 12.9353, "lng": 77.6174},
]


def _dist(h: dict, lat: float, lng: float) -> float:
    """Euclidean distance (fine for short ranges in the same city)."""
    return math.sqrt((h["lat"] - lat) ** 2 + (h["lng"] - lng) ** 2)


def _active_cases(hospital_name: str) -> int:
    """Count currently active ambulances from this hospital."""
    return sum(
        1 for a in _ambulances.values()
        if a["hospital"] == hospital_name and a["status"] not in ("arrived", "cancelled")
    )


def nearest_hospital(user_lat: float, user_lng: float) -> dict:
    """
    Load-balanced hospital selection:
    Primary key  → fewest active cases
    Tiebreaker  → geographic distance
    """
    return min(
        HOSPITALS,
        key=lambda h: (_active_cases(h["name"]), _dist(h, user_lat, user_lng))
    )


# ── OSRM Road Routing ─────────────────────────────────────────────

async def _fetch_road_waypoints(
    from_lat: float, from_lng: float,
    to_lat: float, to_lng: float,
    target_steps: int = 30,
) -> List[dict]:
    """
    Fetch real road-snapped waypoints from OSRM.
    Returns a list of {"lat": ..., "lng": ...} dicts.
    Falls back to straight-line on failure.
    """
    url = (
        f"http://router.project-osrm.org/route/v1/driving/"
        f"{from_lng},{from_lat};{to_lng},{to_lat}"
        f"?overview=full&geometries=geojson&steps=false"
    )
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            resp = await client.get(url)
            data = resp.json()
        coords = data["routes"][0]["geometry"]["coordinates"]  # [[lng, lat], ...]
        # Downsample/upsample to target_steps evenly spaced waypoints
        if len(coords) < 2:
            raise ValueError("Too few coords")
        pts = [{"lat": c[1], "lng": c[0]} for c in coords]
        return _resample(pts, target_steps)
    except Exception as e:
        print(f"[OSRM] Routing failed ({e}), falling back to straight-line")
        return _straight_line_waypoints(from_lat, from_lng, to_lat, to_lng, target_steps)


def _resample(pts: List[dict], n: int) -> List[dict]:
    """Evenly resample a polyline to exactly n waypoints."""
    if len(pts) >= n:
        idxs = [round(i * (len(pts) - 1) / (n - 1)) for i in range(n)]
        return [pts[i] for i in idxs]
    # Interpolate between existing points to fill
    result = []
    total_segs = n - 1
    seg_count = len(pts) - 1
    for i in range(n):
        t = i / total_segs * seg_count
        lo = min(int(t), seg_count - 1)
        hi = min(lo + 1, seg_count)
        frac = t - lo
        result.append({
            "lat": pts[lo]["lat"] + (pts[hi]["lat"] - pts[lo]["lat"]) * frac,
            "lng": pts[lo]["lng"] + (pts[hi]["lng"] - pts[lo]["lng"]) * frac,
        })
    return result


def _straight_line_waypoints(
    from_lat: float, from_lng: float,
    to_lat: float, to_lng: float,
    n: int,
) -> List[dict]:
    return [
        {
            "lat": from_lat + (to_lat - from_lat) * i / (n - 1),
            "lng": from_lng + (to_lng - from_lng) * i / (n - 1),
        }
        for i in range(n)
    ]


# ── Ambulance Dispatch ────────────────────────────────────────────

async def dispatch_ambulance(
    sos_id: str,
    hospital: dict,
    user_lat: float,
    user_lng: float,
    total_steps: int = 30,
) -> None:
    eta_min = round(total_steps * 3 / 60, 1)

    _ambulances[sos_id] = {
        "sos_id":           sos_id,
        "hospital":         hospital["name"],
        "status":           "dispatched",
        "step":             0,
        "total_steps":      total_steps,
        "current_lat":      hospital["lat"],
        "current_lng":      hospital["lng"],
        "destination_lat":  user_lat,
        "destination_lng":  user_lng,
        "eta_minutes":      eta_min,
        "dispatched_at":    datetime.now(timezone.utc).isoformat(),
        "traffic_corridor": None,
        "route_type":       "fetching",
    }

    # Fetch road-snapped waypoints from OSRM
    waypoints = await _fetch_road_waypoints(
        hospital["lat"], hospital["lng"],
        user_lat, user_lng,
        total_steps,
    )
    _ambulances[sos_id]["route_type"] = "road" if len(waypoints) > 2 else "straight"
    _ambulances[sos_id]["waypoints"] = [
        {"lat": w["lat"], "lng": w["lng"]} for w in waypoints
    ]

    # Request green corridor from traffic control
    corridor = await request_green_corridor(
        sos_id, hospital["name"],
        user_lat, user_lng,
        hospital["lat"], hospital["lng"],
        eta_min)
    _ambulances[sos_id]["traffic_corridor"] = corridor

    for step, wp in enumerate(waypoints, start=1):
        await asyncio.sleep(3)
        eta = round((total_steps - step) * 3 / 60, 1)
        status = "arrived" if step == len(waypoints) else "en_route"

        _ambulances[sos_id].update({
            "step":        step,
            "current_lat": wp["lat"],
            "current_lng": wp["lng"],
            "eta_minutes": eta,
            "status":      status,
        })

        await update_ambulance_position(sos_id, wp["lat"], wp["lng"], eta, step)
        print(f"[AMBULANCE] {sos_id} step {step}/{len(waypoints)} "
              f"({wp['lat']:.5f},{wp['lng']:.5f}) ETA {eta} min")

    await release_green_corridor(sos_id)


def get_ambulance_status(sos_id: str) -> Optional[dict]:
    return _ambulances.get(sos_id)


def get_all_ambulances() -> List[dict]:
    # Strip the raw waypoints list from API responses (too large)
    result = []
    for a in _ambulances.values():
        copy = {k: v for k, v in a.items() if k != "waypoints"}
        result.append(copy)
    return result
