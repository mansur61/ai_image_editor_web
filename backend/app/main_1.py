from fastapi import FastAPI, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uuid


from datetime import datetime


# Mock proxy import
from .fal_proxy import create_edit_job as mock_create_job
from .fal_proxy import get_job as mock_get_job
from .fal_proxy import list_jobs as mock_list_jobs

app = FastAPI(title="AI Image Editor Backend (Mock)")

# ------------------------------------------------------
# CORS ayarları
# ------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # frontend domainini buraya ekle
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ------------------------------------------------------
# Root
# ------------------------------------------------------
@app.get("/")
def root():
    return {"message": "Backend (Mock) is running"}

# ------------------------------------------------------
# Job oluşturma
# ------------------------------------------------------
@app.post("/api/jobs")
async def create_job(image: UploadFile, prompt: str = Form(...)):
    """
    Gerçek fal.ai çağrısı yerine mock kullanır.
    """
    # image parametresi kullanılmıyor mockta
    job = await mock_create_job(image, prompt)
    return job

# ------------------------------------------------------
# Job sorgulama
# ------------------------------------------------------
@app.get("/api/jobs/{job_id}")
async def get_job_route(job_id: str):
    job = await mock_get_job(job_id)
    return job

# ------------------------------------------------------
# Tüm joblar
# ------------------------------------------------------
@app.get("/api/jobs")
async def list_jobs_route():
    jobs = await mock_list_jobs()
    return jobs
