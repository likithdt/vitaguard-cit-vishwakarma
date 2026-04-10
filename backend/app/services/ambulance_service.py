import asyncio, math
from typing import Dict, List, Optional
from datetime import datetime, timezone
from app.services.traffic_service import (
    request_green_corridor, update_ambulance_position, release_green_corridor)

_ambulances: Dict[str, dict] = {}

HOSPITALS = [
    {"name": "Apollo Hospital",     "lat": 12.9252, "lng": 77.6011},
    {"name": "Fortis Hospital",     "lat": 12.9611, "lng": 77.6387},
    {"name": "Manipal Hospital",    "lat": 12.9591, "lng": 77.6473},
    {"name": "Narayana Health",     "lat": 12.8938, "lng": 77.5949},
    {"name": "St. John's Hospital", "lat": 12.9353, "lng": 77.6174},
]

def nearest_hospital(user_lat: float, user_lng: float) -> dict:
    def dist(h):
        return math.sqrt((h["lat"] - user_lat)**2 + (h["lng"] - user_lng)**2)
    return min(HOSPITALS, key=dist)

def interpolate(start: float, end: float, t: float) -> float:
    return start + (end - start) * t

async def dispatch_ambulance(
    sos_id: str,
    hospital: dict,
    user_lat: float,
    user_lng: float,
    total_steps: int = 20,
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
    }

    # Request green corridor from traffic control
    corridor = await request_green_corridor(
        sos_id, hospital["name"],
        user_lat, user_lng,
        hospital["lat"], hospital["lng"],
        eta_min)
    _ambulances[sos_id]["traffic_corridor"] = corridor

    for step in range(1, total_steps + 1):
        await asyncio.sleep(3)
        t = step / total_steps
        new_lat = interpolate(hospital["lat"], user_lat, t)
        new_lng = interpolate(hospital["lng"], user_lng, t)
        eta     = round((total_steps - step) * 3 / 60, 1)
        status  = "arrived" if step == total_steps else "en_route"

        _ambulances[sos_id].update({
            "step":        step,
            "current_lat": new_lat,
            "current_lng": new_lng,
            "eta_minutes": eta,
            "status":      status,
        })

        # Update traffic control with position
        await update_ambulance_position(sos_id, new_lat, new_lng, eta, step)

        print(f"[AMBULANCE] {sos_id} step {step}/{total_steps} ETA {eta} min")

    # Release green corridor on arrival
    await release_green_corridor(sos_id)

def get_ambulance_status(sos_id: str) -> Optional[dict]:
    return _ambulances.get(sos_id)

def get_all_ambulances() -> List[dict]:
    return list(_ambulances.values())
