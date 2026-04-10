from fastapi import APIRouter, Depends, BackgroundTasks
from app.middleware.auth_guard import verify_firebase_token
from app.database import get_db
from app.services.sms_service import send_sos_sms, send_family_alert
from app.services.ambulance_service import dispatch_ambulance, get_ambulance_status, get_all_ambulances, nearest_hospital
from app.services.traffic_service import get_traffic_log, get_active_corridors
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timezone
router = APIRouter()

class SosRequest(BaseModel):
    alert_message: str
    location: Optional[dict] = None

@router.post("/trigger")
async def trigger_sos(req: SosRequest, bg: BackgroundTasks, uid: str = Depends(verify_firebase_token)):
    db   = get_db()
    user = await db.users.find_one({"uid":uid})
    lat  = req.location.get("lat",12.9716) if req.location else 12.9716
    lng  = req.location.get("lng",77.5946) if req.location else 77.5946
    location = {"lat":lat,"lng":lng}
    hospital = nearest_hospital(lat,lng)
    sos_event = {"user_id":uid,"alert_message":req.alert_message,"location":location,
                 "hospital":hospital,"status":"triggered","timestamp":datetime.now(timezone.utc),
                 "cancelled":False,"sms_sent":False,"ambulance_dispatched":False}
    result = await db.sos_events.insert_one(sos_event)
    sos_id = str(result.inserted_id)
    patient_name = user.get("full_name","Patient") if user else "Patient"
    family_phone = user.get("emergency_contact_phone","") if user else ""
    family_name  = user.get("emergency_contact_name","") if user else ""

    async def do_all():
        await send_sos_sms(family_phone, patient_name, req.alert_message, location)
        if family_phone:
            await send_family_alert(family_phone, family_name, patient_name, req.alert_message, location)
        await db.sos_events.update_one({"_id":result.inserted_id},{"$set":{"sms_sent":True}})
        await dispatch_ambulance(sos_id, hospital, lat, lng)
        await db.sos_events.update_one({"_id":result.inserted_id},
            {"$set":{"ambulance_dispatched":True,"status":"ambulance_en_route"}})

    bg.add_task(do_all)
    return {"sos_id":sos_id,"status":"triggered","hospital":hospital,"location":location}

@router.get("/ambulance/{sos_id}")
async def ambulance_status(sos_id: str):
    status = get_ambulance_status(sos_id)
    return status or {"status":"not_found"}

@router.get("/ambulances")
async def all_ambulances(): return get_all_ambulances()

@router.get("/traffic/log")
async def traffic_log(): return get_traffic_log()

@router.get("/traffic/corridors")
async def active_corridors(): return get_active_corridors()

@router.get("/history")
async def sos_history(uid: str = Depends(verify_firebase_token)):
    db = get_db()
    cursor = db.sos_events.find({"user_id":uid},sort=[("timestamp",-1)],limit=20,projection={"_id":0})
    return await cursor.to_list(length=20)
