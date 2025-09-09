from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import pymysql, boto3, json, os, threading, time
from botocore.exceptions import ClientError
from dotenv import load_dotenv
from contextlib import asynccontextmanager

load_dotenv()

# --- ENV ---
SECRET_NAME = os.getenv("SECRET_NAME")
DB_HOST     = os.getenv("DB_HOST")
DB_NAME     = os.getenv("DB_NAME", "database_1")
AWS_REGION  = os.getenv("AWS_REGION", "us-east-1")

# Fail fast on missing env
for k in ("SECRET_NAME", "DB_HOST"):
    if not globals()[k]:
        raise RuntimeError(f"Missing required env var: {k}")

# --- Secrets cache (simple) ---
_SECRET_CACHE = None
_SECRET_TS = 0
_SECRET_TTL_SEC = 300  # refresh every 5 minutes; adjust as you like
_secret_lock = threading.Lock()

def get_secret():
    global _SECRET_CACHE, _SECRET_TS
    with _secret_lock:
        if _SECRET_CACHE and (time.time() - _SECRET_TS) < _SECRET_TTL_SEC:
            return _SECRET_CACHE
        try:
            client = boto3.client("secretsmanager", region_name=AWS_REGION)
            sec = client.get_secret_value(SecretId=SECRET_NAME)["SecretString"]
            _SECRET_CACHE = json.loads(sec)
            _SECRET_TS = time.time()
            return _SECRET_CACHE
        except ClientError as e:
            print("[bootstrap] Secrets Manager error:", e)
            raise HTTPException(status_code=500, detail="Failed to read DB secret")

TABLE_SQL = """
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  password VARCHAR(255) NOT NULL
) ENGINE=InnoDB;
"""

def _ensure_table(conn):
    with conn.cursor() as cur:
        cur.execute(TABLE_SQL)
    conn.commit()
    print(f"[bootstrap] Ensured table `{DB_NAME}.users`")

def get_connection():
    creds = get_secret()
    try:
        conn = pymysql.connect(
            host=DB_HOST,
            user=creds["username"],
            password=creds["password"],
            database=DB_NAME,
            autocommit=False,  # we'll commit after CREATE TABLE / writes
            cursorclass=pymysql.cursors.DictCursor,
            connect_timeout=5,
            read_timeout=10,
            write_timeout=10,
            # Optional TLS (mount RDS CA and uncomment):
            # ssl={"ca": "/etc/ssl/certs/rds-combined-ca-bundle.pem"},
        )
        _ensure_table(conn)  # idempotent; cheap
        return conn
    except pymysql.MySQLError as e:
        print("DB connection failed:", e)
        raise HTTPException(status_code=500, detail=str(e))

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Try once at startup; if this fails, first request will still create the table.
    try:
        conn = get_connection()
        conn.close()
        print("[bootstrap] Table check/creation succeeded at startup.")
    except Exception as e:
        print("[bootstrap] Startup ensure failed (will retry on first request):", e)
    yield
    # Optional: add shutdown logic here

app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"],
)

class User(BaseModel):
    name: str
    password: str

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
