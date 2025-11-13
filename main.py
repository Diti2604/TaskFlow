import os, time, json, threading, math, pymysql, boto3 
from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from botocore.exceptions import ClientError
from dotenv import load_dotenv
from typing import Optional
from passlib.hash import bcrypt
from datetime import datetime, timedelta
from jose import JWTError, jwt


load_dotenv()

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],    
    allow_credentials=True,
    allow_methods=["*"],         
    allow_headers=["*"]
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
# NEW auth config
JWT_SECRET = os.getenv("JWT_SECRET", "change-this-secret")
JWT_ALGO = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24

def hash_password(p: str) -> str:
    return bcrypt.hash(p)

def verify_password(p: str, h: str) -> bool:
    return bcrypt.verify(p, h)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, JWT_SECRET, algorithm=JWT_ALGO)

def get_current_user(authorization: Optional[str] = Header(None)):
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing auth header")
    try:
        scheme, token = authorization.split()
        if scheme.lower() != "bearer":
            raise HTTPException(status_code=401, detail="Invalid auth scheme")
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGO])
        username = payload.get("sub")
        if not username:
            raise HTTPException(status_code=401, detail="Invalid token")
    except (ValueError, JWTError):
        raise HTTPException(status_code=401, detail="Invalid token")
    # fetch user row to validate exists
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, name FROM users WHERE name=%s", (username,))
            row = cur.fetchone()
    finally:
        try: conn.close()
        except: pass
    if not row:
        raise HTTPException(status_code=401, detail="User not found")
    return row

# Modify _ensure_db_and_table to create proper schema (password_hash, projects, tasks, analytics)
def _ensure_db_and_table():
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
                    name VARCHAR(255) NOT NULL UNIQUE,
                    password_hash VARCHAR(255) NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS projects (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    owner_id INT NOT NULL,
                    name VARCHAR(255) NOT NULL,
                    description TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    UNIQUE KEY (owner_id, name),
                    INDEX (created_at)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS tasks (
                    id BIGINT AUTO_INCREMENT PRIMARY KEY,
                    project_id INT NOT NULL,
                    title VARCHAR(255) NOT NULL,
                    description TEXT,
                    status VARCHAR(50) DEFAULT 'todo',
                    assignee_id INT NULL,
                    due_date DATE NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    INDEX (project_id), INDEX (status)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS analytics_events (
                    id BIGINT AUTO_INCREMENT PRIMARY KEY,
                    project_id INT NULL,
                    event_type VARCHAR(128) NOT NULL,
                    payload JSON,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    INDEX (project_id),
                    INDEX (event_type),
                    INDEX (created_at)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
        _log("DB schema ensured.")
    finally:
        try: conn_db.close()
        except Exception: pass

def _bootstrap_worker(max_minutes=15):
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
    
# FAIL_STARTUP = os.getenv("FAIL_STARTUP", "false").lower() == "true"   

# @app.on_event("startup")
# def startup():
#     if FAIL_STARTUP:
#         raise RuntimeError("FAIL_STARTUP: intentional crash")
#     threading.Thread(target=_bootstrap_worker, daemon=True).start()


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
    return {"message": "Hello from FastAPI on EC2!!"}   # was a set literal

# Update create_user and login routes to use hashing + JWT
@app.post("/users")
def create_user(user: User):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            ph = hash_password(user.password)
            cur.execute(
                "INSERT INTO users (name, password_hash) VALUES (%s, %s)",
                (user.name, ph),
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
                "SELECT * FROM users WHERE name=%s",
                (user.name,),
            )
            row = cur.fetchone()
    finally:
        try: conn.close()
        except Exception: pass
    if not row or not verify_password(user.password, row.get("password_hash")):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token = create_access_token({"sub": user.name})
    return {"access_token": token, "token_type": "bearer"}

# Minimal projects endpoints
class ProjectIn(BaseModel):
    name: str
    description: Optional[str] = None

class TaskIn(BaseModel):
    title: str
    description: Optional[str] = None

@app.post("/api/projects")
def create_project(p: ProjectIn, user = Depends(get_current_user)):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("INSERT INTO projects (owner_id, name, description) VALUES (%s,%s,%s)",
                        (user["id"], p.name, p.description))
            pid = cur.lastrowid
            cur.execute("SELECT * FROM projects WHERE id=%s", (pid,))
            row = cur.fetchone()
    finally:
        try: conn.close()
        except: pass
    return row

@app.get("/api/projects")
def list_projects(user = Depends(get_current_user)):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM projects WHERE owner_id=%s", (user["id"],))
            rows = cur.fetchall()
    finally:
        try: conn.close()
        except: pass
    return rows

@app.post("/api/projects/{project_id}/tasks")
def add_task(project_id: int, t: TaskIn, user = Depends(get_current_user)):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("INSERT INTO tasks (project_id, title, description) VALUES (%s,%s,%s)",
                        (project_id, t.title, t.description))
            cur.execute("SELECT * FROM tasks WHERE id=%s", (cur.lastrowid,))
            row = cur.fetchone()
    finally:
        try: conn.close()
        except: pass
    return row