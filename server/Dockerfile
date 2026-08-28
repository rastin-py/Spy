FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /srv

# Dependencies first, so editing a pack does not reinstall FastAPI.
COPY pyproject.toml ./
RUN pip install --no-cache-dir \
    "fastapi>=0.115" "uvicorn[standard]>=0.32" \
    "pydantic>=2.9" "pydantic-settings>=2.6" "sqlalchemy>=2.0"

COPY app ./app
COPY content ./content

EXPOSE 8000

# One worker: the catalogue is a few hundred kilobytes held in memory, and
# there is nothing here that blocks. Scale with replicas, not workers.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
