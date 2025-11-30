"""Pydantic response models for the Quran Muaalem API."""

from pydantic import BaseModel


class SingleUnitSchema(BaseModel):
    """A single phonetic feature unit."""

    text: str
    prob: float
    idx: int


class SifaSchema(BaseModel):
    """Phonetic features (sifat) for a phoneme group."""

    phonemes_group: str
    index: int
    hams_or_jahr: SingleUnitSchema | None = None
    shidda_or_rakhawa: SingleUnitSchema | None = None
    tafkheem_or_taqeeq: SingleUnitSchema | None = None
    itbaq: SingleUnitSchema | None = None
    safeer: SingleUnitSchema | None = None
    qalqla: SingleUnitSchema | None = None
    tikraar: SingleUnitSchema | None = None
    tafashie: SingleUnitSchema | None = None
    istitala: SingleUnitSchema | None = None
    ghonna: SingleUnitSchema | None = None


class PhonemeUnitSchema(BaseModel):
    """Predicted phoneme sequence with probabilities."""

    text: str
    probs: list[float]
    ids: list[int]


class MoshafSchema(BaseModel):
    """Moshaf attributes used for phonetization."""

    rewaya: str
    madd_monfasel_len: int
    madd_mottasel_len: int
    madd_mottasel_waqf: int
    madd_aared_len: int


class PhoneticScriptSchema(BaseModel):
    """Reference phonetic script info."""

    phonemes_text: str


class ReferenceSchema(BaseModel):
    """Reference information for the analyzed verse."""

    sura: int | None = None
    aya: int | None = None
    uthmani_text: str
    moshaf: MoshafSchema
    phonetic_script: PhoneticScriptSchema


class AnalyzeResponse(BaseModel):
    """Response model for analyze endpoints."""

    phonemes_text: str
    phonemes: PhonemeUnitSchema
    sifat: list[SifaSchema]
    reference: ReferenceSchema


class ErrorResponse(BaseModel):
    """Error response model."""

    detail: str

