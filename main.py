from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import os, json, time
import pymysql
import boto3
from botocore.exceptions import ClientError
from dotenv import load_dotenv

load_dotenv()

# ---- ENV (wired by your GitHub Action via `kubectl set env`) ----
SECRET_NAME        = os.getenv("SECRET_NAME")            # ARN or name of the RDS master secret
DATABASE_ENDPOINT  = os.getenv("DATABASE_ENDPOINT")      # RDS endpoint address
DB_NAME            = os.getenv("DB_NAME", "database_1")  # DB created by TF (or on first run)
AWS_REGION         = os.getenv("AWS_REGION", "us-east-1")

# Fail fast on missing required envs
for k in ("SECRET_NAME", "DATABASE_ENDPOINT"):
    if not globals()[k]:
        raise RuntimeError(f"Missing required env var: {k}")

# ---- FastAPI app ----
app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"],
)

class User(BaseModel):
    name: str
    password: str

# ---- Secrets Manager (simple cache to avoid calling every request) ----
_SECRET_CACHE = None
_SECRET_TS    = 0.0
_SECRET_TTL   = 300  # seconds

def get_db_creds():
    global _SECRET_CACHE, _SECRET_TS
    now = time.time()
    if _SECRET_CACHE and (now - _SECRET_TS) < _SECRET_TTL:
        return _SECRET_CACHE
    try:
        sm = boto3.client("secretsmanager", region_name=AWS_REGION)
        resp = sm.get_secret_value(SecretId=SECRET_NAME)
        _SECRET_CACHE = json.loads(resp["SecretString"])  # {"username": "...", "password": "..."}
        _SECRET_TS = now
        return _SECRET_CACHE
    except ClientError as e:
        print("[bootstrap] Secrets Manager error:", e)
        raise HTTPException(status_code=500, detail="Failed to read DB secret")

# ---- Schema bootstrap ----
TABLE_SQL = """
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  password VARCHAR(255) NOT NULL
);
""".strip()

def ensure_db_and_table(creds):
    # 1) Ensure the database exists
    conn = pymysql.connect(
        host=DATABASE_ENDPOINT,
        user=creds["username"],
        password=creds["password"],
        autocommit=True,
        connect_timeout=5,
    )
    try:
        with conn.cursor() as cur:
            cur.execute(f"CREATE DATABASE IF NOT EXISTS `{DB_NAME}`;")
    finally:
        conn.close()

    # 2) Ensure the users table exists
    conn = pymysql.connect(
        host=DATABASE_ENDPOINT,
        user=creds["username"],
        password=creds["password"],
        database=DB_NAME,
        autocommit=True,
        connect_timeout=5,
    )
    try:
        with conn.cursor() as cur:
            cur.execute(TABLE_SQL)
        print(f"[bootstrap] Ensured `{DB_NAME}.users`")
    finally:
        conn.close()

def get_connection():
    creds = get_db_creds()
    # Ensure schema (idempotent, cheap)
    ensure_db_and_table(creds)
    try:
        return pymysql.connect(
            host=DATABASE_ENDPOINT,
            user=creds["username"],
            password=creds["password"],
            database=DB_NAME,
            cursorclass=pymysql.cursors.DictCursor,
            connect_timeout=5,
            read_timeout=10,
            write_timeout=10,
            # Optional TLS (mount RDS CA and uncomment):
            # ssl={"ca": "/etc/ssl/certs/rds-combined-ca-bundle.pem"},
        )
    except pymysql.MySQLError as e:
        print("DB connection failed:", e)
        raise HTTPException(status_code=500, detail=str(e))

# ---- Routes ----
@app.get("/")
def root():
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
