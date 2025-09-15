import os, time, json, threading, math, pymysql, boto3
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from botocore.exceptions import ClientError
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=[""], allow_credentials=True, allow_methods=[""], allow_headers=["*"]
)

SECRET_NAME   = os.getenv("SECRET_NAME")        
DATABASE_HOST = os.getenv("DATABASE_HOST")     
AWS_REGION    = os.getenv("AWS_REGION", "us-east-1")
DB_NAME       = os.getenv("DB_NAME", "database_1")
BOOTSTRAP_ON_START = os.getenv("BOOTSTRAP_ON_START", "true").lower() == "true"

class User(BaseModel):
    name: str
    password: str

def _log(msg): 
    print(f"[bootstrap] {msg}", flush=True)

def get_secret():
    if not SECRET_NAME:
        raise RuntimeError("SECRET_NAME not set")
    client = boto3.client("secretsmanager", region_name=AWS_REGION)
    res = client.get_secret_value(SecretId=SECRET_NAME)
    return json.loads(res["SecretString"])

def connect_mysql(host, user, password, database=None):
    return pymysql.connect(
        host=host,
        user=user,
        password=password,
        database=database,
        autocommit=True,
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=10,
    )
def _ensure_db_and_table():
    """Idempotent creation of DB and users table."""
    creds = get_secret()
    user, password = creds["username"], creds["password"]

    conn = connect_mysql(DATABASE_HOST, user, password, database=None)
    try:
        with conn.cursor() as cur:
            cur.execute(
                f"CREATE DATABASE IF NOT EXISTS {DB_NAME} "
                "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
            )
        _log(f"Database {DB_NAME} ensured.")
    finally:
        try: conn.close()
        except Exception: pass


    conn_db = connect_mysql(DATABASE_HOST, user, password, database=DB_NAME)
    try:
        conn_db.ping(reconnect=True)
        with conn_db.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(255) NOT NULL,
                    password VARCHAR(255) NOT NULL
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
        _log("Table users ensured.")
    finally:
        try: conn_db.close()
        except Exception: pass

def _bootstrap_worker(max_minutes=15):
    """Retry bootstrap in background without killing the process."""
    if not (SECRET_NAME and DATABASE_HOST):
        _log("Missing env vars; skip bootstrap.")
        return

    deadline = time.time() + max_minutes * 60
    attempt = 0
    while time.time() < deadline:
        attempt += 1
        try:
            _log(f"Attempt {attempt}: ensuring DB/table...")
            _ensure_db_and_table()
            _log("Bootstrap complete.")
            return
        except ClientError as e:
            code = e.response.get("Error", {}).get("Code")
            _log(f"AWS SecretsManager error ({code}). Will retry.")
        except Exception as e:
            _log(f"Bootstrap failed: {e}. Will retry.")

        sleep_s = min(30, 2 ** attempt)
        time.sleep(sleep_s)

    _log("Bootstrap timed out; app will continue serving without it.")

@app.on_event("startup")
def startup():
    if not BOOTSTRAP_ON_START:
        _log("BOOTSTRAP_ON_START=false; skipping schema bootstrap.")
        return
    threading.Thread(target=_bootstrap_worker, daemon=True).start()

def get_connection():
    try:
        creds = get_secret()
        conn = connect_mysql(DATABASE_HOST, creds["username"], creds["password"], database=DB_NAME)
        conn.ping(reconnect=True)
        return conn
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"DB connection failed: {e}")

@app.get("/")
def root():
    return {"Hello from FastAPI on EC233"}

@app.post("/users")
def create_user(user: User):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO users (name, password) VALUES (%s, %s)",
                (user.name, user.password),
            )
    finally:
        try: conn.close()
        except Exception: pass
    return {"message": "User created"}

@app.post("/login")
def login(user: User):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT * FROM users WHERE name=%s AND password=%s",
                (user.name, user.password),
            )
            row = cur.fetchone()
    finally:
        try: conn.close()
        except Exception: pass
    if not row:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return {"message": f"Welcome, {user.name}!"}