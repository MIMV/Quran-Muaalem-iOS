from dataclasses import dataclass
import torch


@dataclass
class Unit:
    """
    probs: 1D tensors
    """

    text: str
    probs: torch.FloatTensor | list[float]
    ids: torch.LongTensor | list[int]


@dataclass
class SingleUnit:
    """
    A dataclass representing the predicted phoneme sequence with:
        text (str): Concatenated string of all phonemes.
        probs (Union[torch.FloatTensor, list[float]]):
            Confidence probabilities for each predicted phoneme (1D tensor).
        ids (Union[torch.LongTensor, list[int]]) (1D tensor):
            Token IDs corresponding to each phoneme.

    """

    text: str
    prob: float
    idx: int


@dataclass
class Sifa:
    """
    following optional properties (each is a SingleUnit or None):
        - phonemes_group (str): the phonemes associated with the `sifa`
        - hams_or_jahr (SingleUnit): either `hams` or `jahr`
        - shidda_or_rakhawa (SingleUnit): either `shadeed`, `between`, or `rikhw`
        - tafkheem_or_taqeeq (SingleUnit): either `mofakham`, `moraqaq`, or `low_mofakham`
        - itbaq (SingleUnit): either `monfateh`, or `motbaq`
        - safeer (SingleUnit): either `safeer`, or `no_safeer`
        - qalqla (SingleUnit): eithr `moqalqal`, or `not_moqalqal`
        - tikraar (SingleUnit): either `mokarar` or `not_mokarar`
        - tafashie (SingleUnit): either `motafashie`, or `not_motafashie`
        - istitala (SingleUnit): either `mostateel`, or `not_mostateel`
        - ghonna (SingleUnit): either `maghnoon`, or `not_maghnoon`

    Each SingleUnit in Sifa properties contains:
        text (str): The feature's categorical label (e.g., "hams", "shidda").
        prob (float): Confidence probability for this feature.
        idx (int): Identifier for the feature class.

    """

    phonemes_group: str
    hams_or_jahr: SingleUnit | None
    shidda_or_rakhawa: SingleUnit | None
    tafkheem_or_taqeeq: SingleUnit | None
    itbaq: SingleUnit | None
    safeer: SingleUnit | None
    qalqla: SingleUnit | None
    tikraar: SingleUnit | None
    tafashie: SingleUnit | None
    istitala: SingleUnit | None
    ghonna: SingleUnit | None


@dataclass
class MuaalemOutput:
    """
    text (str): The feature's categorical label (e.g., "hams", "shidda").
    prob (float): Confidence probability for this feature.
    idx (int): Identifier for the feature class.
    """

    phonemes: Unit
    sifat: list[Sifa]
