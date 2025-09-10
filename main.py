from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import pymysql, boto3, json, os
from botocore.exceptions import ClientError
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

SECRET_NAME=os.getenv('rds!db-ea3da7e7-41b3-47ef-b694-d1aab3a7ebe3')
DATABASE_ENDPOINT=os.getenv('terraform-20250827074154081300000006.cfr8j6vjvsmt.us-east-1.rds.amazonaws.com')
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
            host=DATABASE_ENDPOINT,
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

def create_users_table():
    try:
        conn = get_connection()
        with conn:
            with conn.cursor() as cur:
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS users (
                        id INT AUTO_INCREMENT PRIMARY KEY,
                        name VARCHAR(255) NOT NULL,
                        password VARCHAR(255) NOT NULL
                    )
                """)
            conn.commit()
        print("Users table created successfully")
    except pymysql.MySQLError as e:
        print("Failed to create users table:", str(e))
        
@app.on_event("startup")
def startup_event():
    create_users_table()
