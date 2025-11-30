from dataclasses import dataclass, asdict
from typing import Literal
import json

from quran_transcript import SifaOutput
import quran_transcript.alphabet as alph
import diff_match_patch as dmp
from rich import print
from rich.text import Text
from rich.table import Table
from rich.console import Console

from .muaalem_typing import Sifa
from .modeling.vocab import SIFAT_ATTR_TO_ARABIC_WITHOUT_BRACKETS


@dataclass
class PhonemeGroup:
    ref: str = ""
    out: str = ""
    ref_idx: int | None = None
    out_idx: int | None = None
    tag: Literal["exact", "partial", "insert", "delete"] | None = None

    def get_tag(self):
        if self.ref == "" and self.out == "":
            raise ValueError("The Entire group is empty")
        if self.ref == self.out:
            self.tag = "exact"
        elif self.ref != "" and self.out == "":
            self.tag = "delete"
        elif self.out != "" and self.ref == "":
            self.tag = "insert"
        else:
            self.tag = "partial"
        return self.tag


def merge_same_phoneme_group(ph_groups: list[PhonemeGroup]) -> list[PhonemeGroup]:
    outs = [ph_groups[0]]
    prev_idx = 0
    for curr_idx in range(1, len(ph_groups)):
        # out is part of ref
        if (
            ph_groups[prev_idx].out_idx is not None
            and ph_groups[curr_idx].ref_idx is not None
            and ph_groups[prev_idx].out in ph_groups[curr_idx].ref
        ):
            del outs[-1]
            outs.append(
                PhonemeGroup(
                    ref=ph_groups[curr_idx].ref,
                    ref_idx=ph_groups[curr_idx].ref_idx,
                    out=ph_groups[prev_idx].out,
                    out_idx=ph_groups[prev_idx].out_idx,
                )
            )
        # ref is part of out
        elif (
            ph_groups[prev_idx].ref_idx is not None
            and ph_groups[curr_idx].out_idx is not None
            and ph_groups[prev_idx].ref in ph_groups[curr_idx].out
        ):
            del outs[-1]
            outs.append(
                PhonemeGroup(
                    ref=ph_groups[prev_idx].ref,
                    ref_idx=ph_groups[prev_idx].ref_idx,
                    out=ph_groups[curr_idx].out,
                    out_idx=ph_groups[curr_idx].out_idx,
                )
            )
        else:
            outs.append(ph_groups[curr_idx])
        prev_idx = curr_idx
    return outs


def segment_groups(
    ref_groups: list[str],
    groups: list[str],
    diffs,
) -> list[PhonemeGroup]:
    """Join similar phonmes groups and diffrentiate between groups"""
    ref_counter = 0
    ref_ptr = 0
    ref_group_idx = 0
    out_counter = 0
    out_ptr = 0
    out_group_idx = 0

    out_pairs = []
    for op, data in diffs:
        if op == 0:
            ref_counter += len(data)
            out_counter += len(data)
        elif op == 1:
            out_counter += len(data)
        elif op == -1:
            ref_counter += len(data)

        ref_has_match = True
        out_has_match = True
        while ref_has_match or out_has_match:
            pair = PhonemeGroup()
            if ref_group_idx < len(ref_groups):
                if (ref_counter - ref_ptr) >= len(ref_groups[ref_group_idx]):
                    pair.ref = ref_groups[ref_group_idx]
                    pair.ref_idx = ref_group_idx
                    ref_ptr += len(ref_groups[ref_group_idx])
                    ref_group_idx += 1
                else:
                    ref_has_match = False
            else:
                ref_has_match = False

            if out_group_idx < len(groups):
                if (out_counter - out_ptr) >= len(groups[out_group_idx]):
                    pair.out = groups[out_group_idx]
                    pair.out_idx = out_group_idx
                    out_ptr += len(groups[out_group_idx])
                    out_group_idx += 1
                else:
                    out_has_match = False
            else:
                out_has_match = False

            if pair.ref or pair.out:
                out_pairs.append(pair)
    return merge_same_phoneme_group(out_pairs)


def expalin_sifat(
    sifat: list[Sifa],
    exp_sifat: list[SifaOutput],
    diffs,
):
    table = []
    chunks = [s.phonemes_group for s in sifat]
    exp_chunks = [s.phonemes for s in exp_sifat]

    groups = segment_groups(ref_groups=exp_chunks, groups=chunks, diffs=diffs)
    keys = set(asdict(sifat[0]).keys()) - {"phonemes_group"}
    madd_group = alph.phonetics.alif + alph.phonetics.yaa_madd + alph.phonetics.waw_madd

    for group in groups:
        raw = {}
        tag = group.get_tag()
        if (tag == "exact") or (tag == "partial" and group.ref[0] in madd_group):
            raw["tag"] = "exact"
            raw["phonemes"] = sifat[group.out_idx].phonemes_group
            raw["exp_phonemes"] = exp_sifat[group.ref_idx].phonemes
            for key in keys:
                if getattr(sifat[group.out_idx], key) is not None:
                    raw[f"{key}"] = getattr(sifat[group.out_idx], key).text
                else:
                    raw[f"{key}"] = "None"

                raw[f"exp_{key}"] = getattr(exp_sifat[group.ref_idx], key)
        elif tag in {"partial", "insert"}:
            raw["tag"] = "insert"
            raw["phonemes"] = sifat[group.out_idx].phonemes_group
            raw["exp_phonemes"] = ""
            for key in keys:
                if getattr(sifat[group.out_idx], key) is not None:
                    raw[f"{key}"] = getattr(sifat[group.out_idx], key).text
                else:
                    raw[f"{key}"] = "None"

                raw[f"exp_{key}"] = ""
        if raw:
            table.append(raw)

    # print(json.dumps(table, indent=2, ensure_ascii=False))
    return table


def print_sifat_table(
    table: list[dict],
    lang: Literal["arabic", "english"] = "arabic",
):
    """Print the sifat comparison table with rich highlighting"""
    if not table:
        return

    # Create a rich Table
    rich_table = Table()

    # Get base columns (non-exp keys without 'tag')
    base_keys = [k for k in table[0].keys() if not k.startswith("exp_") and k != "tag"]

    # Add columns
    # rich_table.add_column("Tag", style="cyan")
    for key in base_keys:
        rich_table.add_column(key.replace("_", " ").title())

    # Add rows
    for row in table:
        tag = row["tag"]
        values = []
        for key in base_keys:
            exp_key = f"exp_{key}"
            value = str(row[key])
            if key != "phonemes" and lang == "arabic":
                value = SIFAT_ATTR_TO_ARABIC_WITHOUT_BRACKETS[value]

            # Apply styling based on tag and comparison
            if tag == "exact" and row.get(exp_key) != row[key]:
                values.append(f"[red]{value}[/red]")
            elif tag == "insert":
                values.append(f"[yellow]{value}[/yellow]")
            else:
                values.append(value)

        rich_table.add_row(*values)

    # Print the table
    console = Console()
    console.print(rich_table)


def explain_for_terminal(
    phonemes: str,
    exp_phonemes: str,
    sifat: list[Sifa],
    exp_sifat: list[SifaOutput],
    lang: Literal["arabic", "english"] = "english",
):
    # Create diff-match-patch object
    dmp_obj = dmp.diff_match_patch()

    # Calculate differences
    diffs = dmp_obj.diff_main(exp_phonemes, phonemes)

    # Create a Rich Text object for colored output
    result = Text()

    # Process each difference
    for op, data in diffs:
        if op == dmp_obj.DIFF_EQUAL:
            result.append(data, style="white")
        elif op == dmp_obj.DIFF_INSERT:
            result.append(data, style="green")
        elif op == dmp_obj.DIFF_DELETE:
            result.append(data, style="red strike")

    # Print the result
    print(result)
    sifat_table = expalin_sifat(sifat, exp_sifat, diffs)
    print_sifat_table(sifat_table, lang=lang)  # Add this line to print the table
