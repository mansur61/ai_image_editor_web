# backend/app/fal_proxy.py
# Mock (sahte) fal.ai proxy — internet bağlantısı yoksa kullanılır


import uuid
from datetime import datetime

# Bellekte geçici job listesi tutacağız
mock_jobs = {}

async def create_edit_job(image_file, prompt: str):
    """
    Gerçek fal.ai çağrısı yerine mock job oluşturur.
    """
    job_id = str(uuid.uuid4())
    mock_jobs[job_id] = {
        "id": job_id,
        "prompt": prompt,
        "status": "done",
        "created_at": datetime.utcnow().isoformat(),
        "image_url": "https://placekitten.com/512/512",  # Demo resim
    }
    return {"job_id": job_id}

async def get_job(job_id: str):
    """
    Mock job bilgisini döner.
    """
    job = mock_jobs.get(job_id)
    if not job:
        return {"status": "failed", "error": "Job not found"}
    return job

async def list_jobs():
    """
    Tüm mock işleri döner.
    """
    return list(mock_jobs.values())
