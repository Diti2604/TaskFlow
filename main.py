from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import pymysql, boto3, json, os, threading
from botocore.exceptions import ClientError
from dotenv import load_dotenv

load_dotenv()
app = FastAPI()

# --- ENV ---
SECRET_NAME = os.getenv("SECRET_NAME", "rds!db-xxxxxxxx")
DB_HOST     = os.getenv("DB_HOST", "database-1.xxxxxx.us-east-1.rds.amazonaws.com")
DB_NAME     = os.getenv("DB_NAME", "database_1")
AWS_REGION  = os.getenv("AWS_REGION", "us-east-1")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"],
)

class User(BaseModel):
    name: str
    password: str

# --- Secrets ---
def get_secret():
    try:
        client = boto3.client("secretsmanager", region_name=AWS_REGION)
        sec = client.get_secret_value(SecretId=SECRET_NAME)["SecretString"]
        return json.loads(sec)
    except ClientError as e:
        print("[bootstrap] Secrets Manager error:", e)
        raise HTTPException(status_code=500, detail="Failed to read DB secret")

# --- Ensure users table (idempotent) ---
_schema_ready = False
_schema_lock = threading.Lock()

def ensure_users_table():
    creds = get_secret()

    # Connect to target DB (Terraform created it)
    conn = pymysql.connect(
        host=DB_HOST,
        user=creds["username"],
        password=creds["password"],
        database=DB_NAME,
        autocommit=True,
        cursorclass=pymysql.cursors.DictCursor,
    )
    try:
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS users (
                  id INT AUTO_INCREMENT PRIMARY KEY,
                  name VARCHAR(255) NOT NULL,
                  password VARCHAR(255) NOT NULL
                ) ENGINE=InnoDB;
            """)
        print(f"[bootstrap] Ensured table `{DB_NAME}.users`")
    finally:
        conn.close()

def ensure_schema_once():
    global _schema_ready
    if _schema_ready:
        return
    with _schema_lock:
        if _schema_ready:
            return
        ensure_users_table()
        _schema_ready = True

@app.on_event("startup")
def _startup():
    try:
        ensure_schema_once()
    except Exception as e:
        # Don’t crash startup; keep clear logs
        print("[bootstrap] Failed to ensure schema:", e)

# --- DB conn for handlers ---
def get_connection():
    ensure_schema_once()  # safety net if startup didn’t run
    creds = get_secret()
    try:
        return pymysql.connect(
            host=DB_HOST,
            user=creds["username"],
            password=creds["password"],
            database=DB_NAME,
            cursorclass=pymysql.cursors.DictCursor,
        )
    except pymysql.MySQLError as e:
        print("DB connection failed:", e)
        raise HTTPException(status_code=500, detail=str(e))

# --- Routes ---
@app.get("/")
def read_root():
    return {"message": "Hello from FastAPI on EKS"}

@app.post("/users")
def create_user(user: User):
    conn = get_connection()
    with conn:
        with conn.cursor() as cur:
            cur.execute("INSERT INTO users (name, password) VALUES (%s, %s)", (user.name, user.password))
        conn.commit()
    return {"message": "User created successfully!"}

@app.post("/login")
def login(user: User):
    conn = get_connection()
    with conn:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM users WHERE name=%s AND password=%s", (user.name, user.password))
            row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return {"message": f"Welcome, {user.name}!"}
