"""FastAPI application for Quran Muaalem API."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, File, Form, HTTPException, UploadFile

from .deps import (
    SAMPLING_RATE,
    build_moshaf,
    build_response,
    get_muaalem,
    get_phonetizer_output,
    get_uthmani_from_aya,
    load_model,
    load_wave_from_upload,
)
from .schemas import AnalyzeResponse, ErrorResponse

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events for the FastAPI app."""
    # Startup: Load the model
    logger.info("Starting Quran Muaalem API...")
    load_model()
    yield
    # Shutdown: cleanup if needed
    logger.info("Shutting down Quran Muaalem API...")


app = FastAPI(
    title="Quran Muaalem API",
    description="API for analyzing Quranic recitation using the Muaalem model. "
    "Detects phonetic features, tajweed rules, and pronunciation accuracy.",
    version="0.1.0",
    lifespan=lifespan,
    responses={
        400: {"model": ErrorResponse, "description": "Bad request"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)


@app.get("/")
async def root():
    """Health check endpoint."""
    return {"status": "ok", "message": "Quran Muaalem API is running"}


@app.get("/health")
async def health():
    """Health check endpoint for deployment platforms."""
    return {"status": "healthy"}


@app.post(
    "/api/analyze-by-verse",
    response_model=AnalyzeResponse,
    summary="Analyze recitation by verse reference",
    description="Analyze a Quranic recitation audio file against a specific verse (sura and aya). "
    "The API fetches the verse text automatically and performs phonetic analysis.",
)
async def analyze_by_verse(
    audio: UploadFile = File(..., description="Audio file (wav, mp3, etc.)"),
    sura: int = Form(..., ge=1, le=114, description="Sura number (1-114)"),
    aya: int = Form(..., ge=1, description="Aya number within the sura"),
    rewaya: str = Form("hafs", description="Recitation style"),
    madd_monfasel_len: int = Form(2, description="Length of separated elongation"),
    madd_mottasel_len: int = Form(4, description="Length of connected elongation"),
    madd_mottasel_waqf: int = Form(
        4, description="Length of connected elongation when stopping"
    ),
    madd_aared_len: int = Form(2, description="Length of necessary elongation"),
):
    """
    Analyze a recitation by specifying the verse reference.

    The endpoint:
    1. Loads and resamples the audio to 16kHz mono
    2. Fetches the Uthmani script for the specified verse
    3. Converts the text to phonetic representation
    4. Runs the Muaalem model for analysis
    5. Returns phoneme predictions and phonetic features (sifat)
    """
    logger.info(f"Analyzing recitation for sura {sura}, aya {aya}")

    # Load audio
    wave, _ = load_wave_from_upload(audio, SAMPLING_RATE)

    # Build moshaf attributes
    moshaf = build_moshaf(
        rewaya=rewaya,
        madd_monfasel_len=madd_monfasel_len,
        madd_mottasel_len=madd_mottasel_len,
        madd_mottasel_waqf=madd_mottasel_waqf,
        madd_aared_len=madd_aared_len,
    )

    # Get Uthmani text for the verse
    uthmani_text = get_uthmani_from_aya(sura, aya)
    logger.info(f"Uthmani text: {uthmani_text[:50]}...")

    # Convert to phonetic script
    phonetizer_out = get_phonetizer_output(uthmani_text, moshaf)

    # Run Muaalem model
    try:
        muaalem = get_muaalem()
        outs = muaalem(
            [wave],
            [phonetizer_out],
            sampling_rate=SAMPLING_RATE,
        )
    except Exception as e:
        logger.exception("Error running Muaalem model")
        raise HTTPException(
            status_code=500, detail=f"Model inference failed: {str(e)}"
        ) from e

    if not outs:
        raise HTTPException(status_code=500, detail="Model returned no output")

    # Build and return response
    return build_response(
        out=outs[0],
        phonetizer_out=phonetizer_out,
        moshaf=moshaf,
        uthmani_text=uthmani_text,
        sura=sura,
        aya=aya,
    )


@app.post(
    "/api/analyze-by-text",
    response_model=AnalyzeResponse,
    summary="Analyze recitation by providing text directly",
    description="Analyze a Quranic recitation audio file against provided Uthmani text. "
    "Use this when you have the text directly rather than a verse reference.",
)
async def analyze_by_text(
    audio: UploadFile = File(..., description="Audio file (wav, mp3, etc.)"),
    uthmani_text: str = Form(..., description="Uthmani script text to analyze against"),
    rewaya: str = Form("hafs", description="Recitation style"),
    madd_monfasel_len: int = Form(2, description="Length of separated elongation"),
    madd_mottasel_len: int = Form(4, description="Length of connected elongation"),
    madd_mottasel_waqf: int = Form(
        4, description="Length of connected elongation when stopping"
    ),
    madd_aared_len: int = Form(2, description="Length of necessary elongation"),
):
    """
    Analyze a recitation by providing the Uthmani text directly.

    The endpoint:
    1. Loads and resamples the audio to 16kHz mono
    2. Uses the provided Uthmani text
    3. Converts the text to phonetic representation
    4. Runs the Muaalem model for analysis
    5. Returns phoneme predictions and phonetic features (sifat)
    """
    logger.info(f"Analyzing recitation for text: {uthmani_text[:50]}...")

    if not uthmani_text.strip():
        raise HTTPException(status_code=400, detail="uthmani_text cannot be empty")

    # Load audio
    wave, _ = load_wave_from_upload(audio, SAMPLING_RATE)

    # Build moshaf attributes
    moshaf = build_moshaf(
        rewaya=rewaya,
        madd_monfasel_len=madd_monfasel_len,
        madd_mottasel_len=madd_mottasel_len,
        madd_mottasel_waqf=madd_mottasel_waqf,
        madd_aared_len=madd_aared_len,
    )

    # Convert to phonetic script
    phonetizer_out = get_phonetizer_output(uthmani_text, moshaf)

    # Run Muaalem model
    try:
        muaalem = get_muaalem()
        outs = muaalem(
            [wave],
            [phonetizer_out],
            sampling_rate=SAMPLING_RATE,
        )
    except Exception as e:
        logger.exception("Error running Muaalem model")
        raise HTTPException(
            status_code=500, detail=f"Model inference failed: {str(e)}"
        ) from e

    if not outs:
        raise HTTPException(status_code=500, detail="Model returned no output")

    # Build and return response
    return build_response(
        out=outs[0],
        phonetizer_out=phonetizer_out,
        moshaf=moshaf,
        uthmani_text=uthmani_text,
    )

