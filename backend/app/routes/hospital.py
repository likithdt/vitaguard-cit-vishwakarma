from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from app.database import get_db
from app.services.ambulance_service import get_all_ambulances
from app.services.traffic_service import get_traffic_log, get_active_corridors
from typing import List
import json
router = APIRouter()
_hospital_ws: List[WebSocket] = []

async def notify_hospital(event: dict):
    dead=[]
    for ws in _hospital_ws:
        try:
            payload={k:(str(v) if hasattr(v,'isoformat') else v) for k,v in event.items()}
            await ws.send_text(json.dumps(payload))
        except: dead.append(ws)
    for ws in dead: _hospital_ws.remove(ws)

@router.get("/emergencies")
async def get_emergencies():
    db = get_db()
    cursor = db.sos_events.find({"status":{"$in":["triggered","ambulance_en_route"]}},
        sort=[("timestamp",-1)],limit=50,projection={"_id":0})
    return await cursor.to_list(length=50)

@router.get("/ambulances")
async def hospital_ambulances(): return get_all_ambulances()

@router.get("/stats")
async def hospital_stats():
    db = get_db()
    return {"total_sos": await db.sos_events.count_documents({}),
            "active":    await db.sos_events.count_documents({"status":"ambulance_en_route"}),
            "resolved":  await db.sos_events.count_documents({"status":"resolved"}),
            "total_patients": await db.users.count_documents({})}

@router.get("/traffic/log")
async def traffic_log_hospital(): return get_traffic_log()

@router.get("/traffic/corridors")
async def corridors(): return get_active_corridors()

@router.websocket("/ws")
async def hospital_ws(websocket: WebSocket):
    await websocket.accept()
    _hospital_ws.append(websocket)
    try:
        while True: await websocket.receive_text()
    except WebSocketDisconnect:
        if websocket in _hospital_ws: _hospital_ws.remove(websocket)
