from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import pymysql, boto3, json, os
from botocore.exceptions import ClientError
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

SECRET_NAME=os.getenv('rds!db-36fdb95c-946c-4904-829e-bd311ed03958')
DATABASE_ENDPOINT=os.getenv('database-1.c45skak28aye.us-east-1.rds.amazonaws.com')
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
