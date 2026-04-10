import firebase_admin
from firebase_admin import credentials
from app.config import FIREBASE_CREDENTIALS_PATH
def init_firebase():
    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
        firebase_admin.initialize_app(cred)
        print("Firebase Admin SDK initialized")
