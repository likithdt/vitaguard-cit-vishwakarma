from dotenv import load_dotenv
import os
load_dotenv()
MONGO_URI  = os.getenv("MONGO_URI", "mongodb://localhost:27017")
DB_NAME    = os.getenv("DB_NAME",   "vitalguard")
FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH", "./firebase-adminsdk.json")
