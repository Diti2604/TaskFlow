from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import pymysql, boto3, json, os, threading
from botocore.exceptions import ClientError
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

SECRET_NAME     = os.getenv("SECRET_NAME")
DB_ENDPOINT         = os.getenv("DB_ENDPOINT")
DB_NAME         = os.getenv("DB_NAME", "database_1")
AWS_REGION      = os.getenv("AWS_REGION", "us-east-1")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class User(BaseModel):  
    name: str
    password: str


def get_secret():
    secret_name = SECRET_NAME
    region_name = "us-east-1"

    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        # For a list of exceptions thrown, see
        # https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html
        print("Secrets Manager error: ", str(e))
        raise e
    secret = get_secret_value_response['SecretString']
    secret = json.loads(secret)
    print("Retrieved Secret: ", secret)
    return secret

def get_connection():
    try:
        print(" Starting DB connection...")
        creds = get_secret()
        conn = pymysql.connect(
            host=DB_ENDPOINT,
            user=creds["username"],
            password=creds["password"],
            database="database_1",
            cursorclass=pymysql.cursors.DictCursor
        )
        print("DB connection successful")
        return conn
    except pymysql.MySQLError as e:
        print("DB connection failed:", str(e))
        raise HTTPException(status_code=500, detail=str(e))
    
    
    
def get_secret():
    session = boto3.session.Session()
    client = session.client(service_name='secretsmanager', region_name=AWS_REGION)
    try:
        resp = client.get_secret_value(SecretId=SECRET_NAME)
        secret = json.loads(resp['SecretString'])
        return secret
    except ClientError as e:
        print("Secrets Manager error:", str(e))
        raise HTTPException(status_code=500, detail="Failed to read DB secret")

# --- Schema bootstrap (run once) ---
_schema_ready = False
_schema_lock = threading.Lock()

def ensure_schema():
    """
    Idempotent: creates DB and users table if they don't exist.
    """
    creds = get_secret()

    # 1) connect without database to ensure DB exists
    conn = pymysql.connect(
        host=DB_ENDPOINT, user=creds["username"], password=creds["password"],
        autocommit=True, cursorclass=pymysql.cursors.DictCursor
    )
    try:
        with conn.cursor() as cur:
            cur.execute(f"CREATE DATABASE IF NOT EXISTS `{DB_NAME}`;")
    finally:
        conn.close()

    # 2) connect to target DB and ensure tables
    conn = pymysql.connect(
        host=DB_ENDPOINT, user=creds["username"], password=creds["password"],
        database=DB_NAME, autocommit=True, cursorclass=pymysql.cursors.DictCursor
    )
    try:
        with conn.cursor() as cur:
            cur.execute(f"""
                CREATE TABLE IF NOT EXISTS users (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(255) NOT NULL,
                    password VARCHAR(255) NOT NULL
                ) ENGINE=InnoDB;
            """)
    finally:
        conn.close()

def ensure_schema_once():
    global _schema_ready
    if _schema_ready:
        return
    with _schema_lock:
        if _schema_ready:
            return
        ensure_schema()
        _schema_ready = True

# FastAPI startup hook: build schema before serving traffic
@app.on_event("startup")
def _startup():
    ensure_schema_once()

# --- DB connections for handlers ---
def get_connection():
    try:
        ensure_schema_once()

        creds = get_secret()
        conn = pymysql.connect(
            host=DB_ENDPOINT, user=creds["username"], password=creds["password"],
            database=DB_NAME, cursorclass=pymysql.cursors.DictCursor
        )
        return conn
    except pymysql.MySQLError as e:
        print("DB connection failed:", str(e))
        raise HTTPException(status_code=500, detail=str(e))


    
@app.get("/")
def read_root():
    return {"message": "Hello from FastAPI on EC2"}

@app.post("/users")
def create_user(user: User):
    try:
        conn = get_connection()
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO users (name, password) VALUES (%s, %s)",
                    (user.name, user.password)
                )
            conn.commit()
        return {"message": "User created successfully!"}
    except pymysql.MySQLError as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/login")
def login(user: User):
    try:
        conn = get_connection()
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT * FROM users WHERE name=%s AND password=%s",
                    (user.name, user.password)
                )
                result = cur.fetchone()
        if not result:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        return {"message": f"Welcome, {user.name}!"}
    except pymysql.MySQLError as e:
        raise HTTPException(status_code=500, detail=str(e))
