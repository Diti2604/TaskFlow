from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import pymysql, boto3, json, os
from botocore.exceptions import ClientError
from dotenv import load_dotenv

load_dotenv()
app = FastAPI()

# --- ENV ---
SECRET_NAME = os.getenv("SECRET_NAME")
DB_HOST     = os.getenv("DB_HOST")
DB_NAME     = os.getenv("DB_NAME", "database_1")
AWS_REGION  = os.getenv("AWS_REGION", "us-east-1")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"],
)

class User(BaseModel):
    name: str
    password: str

def get_secret():
    try:
        client = boto3.client("secretsmanager", region_name=AWS_REGION)
        sec = client.get_secret_value(SecretId=SECRET_NAME)["SecretString"]
        return json.loads(sec)
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
    # Called on every fresh connection (cheap, idempotent)
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
            autocommit=False,  # commit after CREATE TABLE
            cursorclass=pymysql.cursors.DictCursor,
        )
        _ensure_table(conn)
        return conn
    except pymysql.MySQLError as e:
        print("DB connection failed:", e)
        raise HTTPException(status_code=500, detail=str(e))

@app.on_event("startup")
def _startup():
    # Try once at startup; if this fails, the first request still creates the table.
    try:
        conn = get_connection()
        conn.close()
    except Exception as e:
        print("[bootstrap] Startup ensure failed (will retry on first request):", e)

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
