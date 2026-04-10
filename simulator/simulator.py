import time, requests, os
from dotenv import load_dotenv
from vitals_generator import generate_vitals
from datetime import datetime

load_dotenv()

API_URL  = os.getenv("API_URL", "http://localhost:8000")
USER_ID  = os.getenv("USER_ID", "LKT01")
INTERVAL = int(os.getenv("INTERVAL", "300"))
HEADERS  = {"Authorization": f"Bearer {USER_ID}", "Content-Type": "application/json"}

def run():
    print(f"VitalGuard Simulator started")
    print(f"  Target:   {API_URL}/vitals")
    print(f"  User ID:  {USER_ID}")
    print(f"  Interval: {INTERVAL}s ({INTERVAL//60} min)\n")
    cycle = 0
    while True:
        cycle += 1
        vitals = generate_vitals(simulate_emergency=(cycle % 10 == 0))
        payload = {
            "user_id":      USER_ID,
            "heart_rate":   vitals["heart_rate"],
            "spO2":         vitals["spo2"],
            "bp_systolic":  vitals["bp_systolic"],
            "bp_diastolic": vitals["bp_diastolic"],
            "glucose":      vitals["glucose"],
            "temperature":  vitals["temperature"],
            "timestamp":    datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        }
        try:
            r    = requests.post(f"{API_URL}/vitals", json=payload, headers=HEADERS, timeout=5)
            data = r.json()
            flag = "ALERT" if data.get("alert_triggered") else "OK"
            ts   = datetime.now().strftime("%H:%M:%S")
            print(f"[{ts}] [{flag}] HR:{payload['heart_rate']} SpO2:{payload['spO2']}% "
                  f"BP:{payload['bp_systolic']}/{payload['bp_diastolic']} "
                  f"Glu:{payload['glucose']} Temp:{payload['temperature']}°C")
            if data.get("alert_message"):
                print(f"         --> {data['alert_message']}")
        except Exception as e:
            print(f"[ERROR] {e}")
        time.sleep(INTERVAL)

if __name__ == "__main__":
    run()
