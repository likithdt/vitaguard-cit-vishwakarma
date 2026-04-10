import os
TWILIO_SID   = os.getenv("TWILIO_ACCOUNT_SID","")
TWILIO_TOKEN = os.getenv("TWILIO_AUTH_TOKEN","")
TWILIO_FROM  = os.getenv("TWILIO_PHONE_FROM","")

async def send_sos_sms(to_phone, patient_name, alert_message, location=None):
    lat=location.get("lat",0) if location else 0
    lng=location.get("lng",0) if location else 0
    body=(f"VITALGUARD EMERGENCY\nPatient: {patient_name}\n"
          f"Alert: {alert_message}\nLocation: https://maps.google.com/?q={lat},{lng}")
    if TWILIO_SID and TWILIO_TOKEN and TWILIO_FROM:
        try:
            from twilio.rest import Client
            msg=Client(TWILIO_SID,TWILIO_TOKEN).messages.create(body=body,from_=TWILIO_FROM,to=to_phone)
            return {"sent":True,"sid":msg.sid}
        except Exception as e:
            return {"sent":False,"error":str(e)}
    else:
        print(f"\n[SMS SIM] To:{to_phone}\n{body}\n")
        return {"sent":True,"mode":"simulation"}

async def send_family_alert(family_phone, family_name, patient_name, alert_message, location=None):
    lat=location.get("lat",0) if location else 0
    lng=location.get("lng",0) if location else 0
    body=(f"URGENT: {patient_name} needs help!\nVitalGuard: {alert_message}\n"
          f"Location: https://maps.google.com/?q={lat},{lng}\nEmergency services notified.")
    if TWILIO_SID and TWILIO_TOKEN and TWILIO_FROM:
        try:
            from twilio.rest import Client
            msg=Client(TWILIO_SID,TWILIO_TOKEN).messages.create(body=body,from_=TWILIO_FROM,to=family_phone)
            return {"sent":True,"sid":msg.sid}
        except Exception as e:
            return {"sent":False,"error":str(e)}
    else:
        print(f"\n[SMS SIM] Family to:{family_phone}\n{body}\n")
        return {"sent":True,"mode":"simulation"}
