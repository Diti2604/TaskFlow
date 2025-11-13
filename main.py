import os, time, json, threading, pymysql, boto3
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
from datetime import date
from botocore.exceptions import ClientError
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://taskflow.indritcloud.com",
        "https://www.taskflow.indritcloud.com",
        "https://api.taskflow.indritcloud.com",
        "http://localhost:5173", 
        "http://localhost:3000",  
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


SECRET_NAME   = os.getenv("SECRET_NAME")        
DATABASE_HOST = os.getenv("DATABASE_HOST")     
AWS_REGION    = os.getenv("AWS_REGION", "us-east-1")
DB_NAME       = os.getenv("DB_NAME", "database_1")
BOOTSTRAP_ON_START = os.getenv("BOOTSTRAP_ON_START", "true").lower() == "true"

# Pydantic models
class UserLogin(BaseModel):
    name: str
    password: str

class UserCreate(BaseModel):
    name: str
    password: str

class ProjectCreate(BaseModel):
    name: str
    description: Optional[str] = ""

class TaskCreate(BaseModel):
    title: str
    description: Optional[str] = ""
    due_date: Optional[str] = None
    assignee_id: Optional[int] = None

class TaskUpdate(BaseModel):
    title: Optional[str] = None
    status: Optional[str] = None
    description: Optional[str] = None
    due_date: Optional[str] = None

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
            # Users table
            cur.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(255) NOT NULL UNIQUE,
                    password VARCHAR(255) NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
            
            # Projects table
            cur.execute("""
                CREATE TABLE IF NOT EXISTS projects (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(255) NOT NULL,
                    description TEXT,
                    user_id INT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
            
            # Tasks table
            cur.execute("""
                CREATE TABLE IF NOT EXISTS tasks (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    project_id INT NOT NULL,
                    title VARCHAR(255) NOT NULL,
                    description TEXT,
                    status VARCHAR(50) DEFAULT 'todo',
                    due_date DATE,
                    assignee_id INT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
                    FOREIGN KEY (assignee_id) REFERENCES users(id) ON DELETE SET NULL
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
        _log("All tables ensured.")
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
    return {"message": "Hello from FastAPI on EC2!!", "status": "healthy"}

# ============= AUTH ENDPOINTS =============
@app.post("/signup")
def signup(user: UserCreate):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            # Check if user already exists
            cur.execute("SELECT id FROM users WHERE name=%s", (user.name,))
            if cur.fetchone():
                raise HTTPException(status_code=400, detail="User already exists")
            
            cur.execute(
                "INSERT INTO users (name, password) VALUES (%s, %s)",
                (user.name, user.password),
            )
            user_id = cur.lastrowid
    finally:
        try: conn.close()
        except Exception: pass
    return {"message": "User created", "user": {"id": user_id, "name": user.name}}

@app.post("/login")
def login(user: UserLogin):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, name FROM users WHERE name=%s AND password=%s",
                (user.name, user.password),
            )
            row = cur.fetchone()
    finally:
        try: conn.close()
        except Exception: pass
    if not row:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return {"message": f"Welcome, {user.name}!", "user": row}

# ============= PROJECT ENDPOINTS =============
@app.get("/api/projects")
def get_projects():
    """Get all projects with their tasks"""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, name, description, created_at FROM projects ORDER BY created_at DESC")
            projects = cur.fetchall()
            
            for project in projects:
                cur.execute(
                    "SELECT id, title, description, status, due_date, assignee_id FROM tasks WHERE project_id=%s ORDER BY created_at",
                    (project['id'],)
                )
                project['tasks'] = cur.fetchall()
    finally:
        try: conn.close()
        except Exception: pass
    return projects

@app.post("/api/projects")
def create_project(project: ProjectCreate):
    """Create a new project"""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO projects (name, description) VALUES (%s, %s)",
                (project.name, project.description),
            )
            project_id = cur.lastrowid
    finally:
        try: conn.close()
        except Exception: pass
    return {"id": project_id, "name": project.name, "description": project.description, "tasks": []}

@app.get("/api/projects/{project_id}")
def get_project(project_id: int):
    """Get a specific project with tasks"""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, name, description, created_at FROM projects WHERE id=%s", (project_id,))
            project = cur.fetchone()
            if not project:
                raise HTTPException(status_code=404, detail="Project not found")
            
            cur.execute(
                "SELECT id, title, description, status, due_date, assignee_id FROM tasks WHERE project_id=%s ORDER BY created_at",
                (project_id,)
            )
            project['tasks'] = cur.fetchall()
    finally:
        try: conn.close()
        except Exception: pass
    return project

@app.patch("/api/projects/{project_id}")
def update_project(project_id: int, project: ProjectCreate):
    """Update a project's name and description"""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE projects SET name=%s, description=%s WHERE id=%s",
                (project.name, project.description, project_id),
            )
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Project not found")
            
            # Get updated project
            cur.execute("SELECT id, name, description, created_at FROM projects WHERE id=%s", (project_id,))
            updated = cur.fetchone()
    finally:
        try: conn.close()
        except Exception: pass
    return updated

# ============= TASK ENDPOINTS =============
@app.post("/api/projects/{project_id}/tasks")
def create_task(project_id: int, task: TaskCreate):
    """Create a new task in a project"""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO tasks (project_id, title, description, due_date, assignee_id) VALUES (%s, %s, %s, %s, %s)",
                (project_id, task.title, task.description, task.due_date, task.assignee_id),
            )
            task_id = cur.lastrowid
    finally:
        try: conn.close()
        except Exception: pass
    return {"id": task_id, "title": task.title, "status": "todo", "project_id": project_id}

@app.patch("/api/tasks/{task_id}")
def update_task(task_id: int, task: TaskUpdate):
    """Update a task"""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            # Build dynamic update query
            updates = []
            params = []
            if task.title is not None:
                updates.append("title=%s")
                params.append(task.title)
            if task.status is not None:
                updates.append("status=%s")
                params.append(task.status)
            if task.description is not None:
                updates.append("description=%s")
                params.append(task.description)
            if task.due_date is not None:
                updates.append("due_date=%s")
                params.append(task.due_date)
            
            if not updates:
                raise HTTPException(status_code=400, detail="No fields to update")
            
            params.append(task_id)
            cur.execute(f"UPDATE tasks SET {', '.join(updates)} WHERE id=%s", params)
            
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Task not found")
            
            # Get updated task
            cur.execute("SELECT id, title, description, status, due_date, project_id FROM tasks WHERE id=%s", (task_id,))
            updated = cur.fetchone()
    finally:
        try: conn.close()
        except Exception: pass
    return updated

@app.delete("/api/tasks/{task_id}")
def delete_task(task_id: int):
    """Delete a task"""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM tasks WHERE id=%s", (task_id,))
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Task not found")
    finally:
        try: conn.close()
        except Exception: pass
    return {"message": "Task deleted"}

# ============= ANALYTICS ENDPOINTS =============
@app.get("/api/analytics")
def get_analytics():
    """Get task analytics"""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT status, COUNT(*) as count 
                FROM tasks 
                GROUP BY status
            """)
            rows = cur.fetchall()
            
            task_status_counts = {
                'todo': 0,
                'in_progress': 0,
                'done': 0
            }
            for row in rows:
                task_status_counts[row['status']] = row['count']
    finally:
        try: conn.close()
        except Exception: pass
    return {"task_status_counts": task_status_counts}