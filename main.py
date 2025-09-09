from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import pymysql, boto3, json, os
from botocore.exceptions import ClientError
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

SECRET_NAME = os.getenv('SECRET_NAME')
DATABASE_ENDPOINT = os.getenv('DATABASE_ENDPOINT')
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
    """Connects to the database and creates the 'users' table if it doesn't exist."""
    conn = None
    max_retries = 5
    retry_delay = 10  # seconds

    for attempt in range(max_retries):
        try:
            print(f"Attempt {attempt + 1}/{max_retries} to connect and set up database...")
            conn = get_connection()
            with conn.cursor() as cur:
                create_table_query = """
                CREATE TABLE IF NOT EXISTS users (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(255) NOT NULL UNIQUE,
                    password VARCHAR(255) NOT NULL
                );
                """
                cur.execute(create_table_query)
                print("✅ Table 'users' created successfully or already exists.")
            conn.commit()
            return # Success, exit the function
        except Exception as e:
            print(f"ERROR: Could not set up table on attempt {attempt + 1}: {e}")
            if attempt < max_retries - 1:
                print(f"Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
            else:
                print("FATAL: Max retries reached. Could not set up database.")
                # You might want to raise the exception to cause the pod to crash and restart
                raise e
        finally:
            if conn:
                conn.close()
                print("⏹️  Database connection closed.")

# --- FastAPI Startup Event ---
@app.on_event("startup")
def on_startup():
    """This function runs once when the application starts."""
    print("🚀 Application starting up...")
    create_users_table()
    print("✅ Startup tasks complete.")