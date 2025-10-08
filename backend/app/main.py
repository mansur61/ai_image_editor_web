import base64
from fastapi import FastAPI, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import aiohttp
import os
import uuid
from dotenv import load_dotenv

load_dotenv()

# ------------------------------------------------------
# Fal.ai API ayarları
# ------------------------------------------------------
FAL_API_KEY = os.getenv("FAL_API_KEY")
# Fal.ai dökümana göre API endpoint:
FAL_API_URL = "https://fal.ai/models/fal-ai/bytedance/seedream/v4/edit/api"

app = FastAPI(title="AI Image Editor Backend")

# ------------------------------------------------------
# CORS ayarları
# ------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # frontend domaini ekleyebilirsiniz
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ------------------------------------------------------
# Basit in-memory job storage
# ------------------------------------------------------
jobs = {}

# ------------------------------------------------------
# Root
# ------------------------------------------------------
@app.get("/")
def root():
    return {"message": "Backend is running"}

# ------------------------------------------------------
# Job oluşturma endpoint (memory üzerinden dosya gönderme)
# ------------------------------------------------------
import base64
from fastapi import FastAPI, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import aiohttp
import os
import uuid
from dotenv import load_dotenv

load_dotenv()

FAL_API_KEY = os.getenv("FAL_API_KEY")
FAL_API_URL = "https://fal.run/fal-ai/bytedance/seedream/v4/edit"

app = FastAPI(title="AI Image Editor Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/api/jobs")
async def create_job(
    prompt: str = Form(...),
    model: str = Form("image-to-image"),
    image: UploadFile = None
):
    job_id = str(uuid.uuid4())

    if not image:
        return JSONResponse(status_code=400, content={"error": "Image file required."})

    image_bytes = await image.read()
    image_base64 = base64.b64encode(image_bytes).decode("utf-8")
    image_data_uri = f"data:{image.content_type};base64,{image_base64}"

    payload = {
        "input": {
            "prompt": prompt,
            "image_url": image_data_uri
        }
    }

    headers = {
        "Authorization": f"Key {FAL_API_KEY}",
        "Content-Type": "application/json"
    }

    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(
                FAL_API_URL,
                headers=headers,
                json=payload,
                timeout=aiohttp.ClientTimeout(total=120)
            ) as response:

                text = await response.text()
                print("Raw Response:", text)

                if response.status != 200:
                    return JSONResponse(status_code=response.status, content={"error": text})

                data = await response.json()
                image_url = data.get("image") or data.get("output", {}).get("image_url")

                return {"job_id": job_id, "status": "done", "result_url": image_url}

    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})


# ------------------------------------------------------
# Job durumu sorgulama
# ------------------------------------------------------
@app.get("/api/jobs/{job_id}")
def get_job(job_id: str):
    job = jobs.get(job_id)
    if not job:
        return JSONResponse(status_code=404, content={"error": "Job not found"})
    return job

# ------------------------------------------------------
# Tüm jobları listeleme
# ------------------------------------------------------
@app.get("/api/jobs")
def list_jobs():
    return jobs
