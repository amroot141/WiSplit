from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import auth, expenses, settlements

app = FastAPI(
    title="WiSplit Expense Engine API",
    description="Core backend for expense splitting and debt minimization powered by FastAPI and Supabase PostgreSQL.",
    version="1.0.0",
)

# CORS Middleware configuration for backend API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(auth.router)
app.include_router(expenses.router)
app.include_router(settlements.router)


@app.get("/health", tags=["Health"])
async def health_check():
    return {"status": "ok", "service": "WiSplit Backend"}
