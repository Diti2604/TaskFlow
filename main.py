from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import pymysql, boto3, json, os, time
from botocore.exceptions import ClientError
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()
SECRET_NAME     = os.getenv("rds!db-5d1555c1-58d8-449e-b0a1-5dd4ddeb1a44")     
DATABASE_HOST   = os.getenv("database-1.cq7muy8ms32x.us-east-1.rds.amazonaws.com")   
AWS_REGION      = os.getenv("AWS_REGION", "us-east-1")
DB_NAME         = os.getenv("DB_NAME", "database_1")

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

def connect_mysql(host: str, user: str, password: str, database: str | None = None):
    return pymysql.connect(
        host=host,
        user=user,
        password=password,
        database=database,
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=10,
    )

def wait_for_rds_ready(user: str, password: str, host: str, max_attempts: int = 30, sleep_seconds: int = 5):
    """
    Try to connect repeatedly (no database specified) until RDS is accepting connections,
    or until attempts are exhausted.
    """
    last_err = None
    for attempt in range(1, max_attempts + 1):
        try:
            conn = connect_mysql(host=host, user=user, password=password, database=None)
            conn.close()
            print(f"RDS is reachable (attempt {attempt}).")
            return
        except Exception as e:
            last_err = e
            print(f"RDS not ready yet (attempt {attempt}/{max_attempts}): {e}")
            time.sleep(sleep_seconds)
    raise RuntimeError(f"RDS did not become ready in time: {last_err}")

def ensure_database_and_table():
    """
    Idempotent: creates DB (if needed) and 'users' table (if needed).
    """
    creds = get_secret()
    user = creds["username"]
    password = creds["password"]

    # 1) Wait for RDS to accept TCP connections
    wait_for_rds_ready(user=user, password=password, host=DATABASE_HOST)

    # 2) Create database if it doesn't exist (connect without DB)
    conn = connect_mysql(host=DATABASE_HOST, user=user, password=password, database=None)
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(f"CREATE DATABASE IF NOT EXISTS {DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
            conn.commit()
        print(f"Database {DB_NAME} ensured.")
    finally:
        conn.close()


    conn_db = connect_mysql(host=DATABASE_HOST, user=user, password=password, database=DB_NAME)
    try:
        with conn_db:
            with conn_db.cursor() as cur:
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS users (
                        id INT AUTO_INCREMENT PRIMARY KEY,
                        name VARCHAR(255) NOT NULL,
                        password VARCHAR(255) NOT NULL
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """)
            conn_db.commit()
        print("Table users ensured.")
    finally:
        conn_db.close()


def get_connection():
    try:
        print(" Starting DB connection...")
        creds = get_secret()
        conn = pymysql.connect(
            host=DATABASE_HOST,
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

@app.on_event("startup")
def bootstrap_db_on_startup():
    """
    Simple and reliable for your use case: when the pod starts,
    wait for RDS, then ensure DB and table exist. Safe to run multiple times.
    """
    if not DATABASE_HOST:
        raise RuntimeError("DATABASE_HOST env var is not set.")
    ensure_database_and_table()
