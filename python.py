from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI()


@app.get("/")
def read_root():
    return {"Hello": "World"}

@app.get("/health")
async def health():
    """health check for target group register fargate task"""
    return JSONResponse(
        content={
            "message": "success",
            
        },
        status_code=200,
    )
