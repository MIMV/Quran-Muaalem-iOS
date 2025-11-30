import pytest
import diff_match_patch as dmp

from quran_muaalem.explain import segment_groups, PhonemeGroup


@pytest.mark.parametrize(
    "ref_str, out_str, ref_groups, out_groups, ex_segments",
    [
        (
            "abcd",
            "abfdm",
            ["ab", "cd"],
            ["ab", "fd", "m"],
            [
                PhonemeGroup(ref="ab", ref_idx=0, out="ab", out_idx=0),
                PhonemeGroup(ref="cd", ref_idx=1, out="fd", out_idx=1),
                PhonemeGroup(out="m", out_idx=2),
            ],
        ),
        (
            "abcd",
            "abcd",
            ["ab", "cd"],
            ["ab", "cd"],
            [
                PhonemeGroup(ref="ab", ref_idx=0, out="ab", out_idx=0),
                PhonemeGroup(ref="cd", ref_idx=1, out="cd", out_idx=1),
            ],
        ),
        (
            "abcd",
            "efgh",
            ["ab", "cd"],
            ["ef", "gh"],
            [
                PhonemeGroup(ref="ab", ref_idx=0, out=""),
                PhonemeGroup(ref="cd", ref_idx=1, out=""),
                PhonemeGroup(ref="", out="ef", out_idx=0),
                PhonemeGroup(ref="", out="gh", out_idx=1),
            ],
        ),
        (
            "abcde",
            "efgh",
            ["ab", "cd", "e"],
            ["ef", "gh"],
            [
                PhonemeGroup(ref="ab", ref_idx=0, out=""),
                PhonemeGroup(ref="cd", ref_idx=1, out=""),
                PhonemeGroup(ref="e", ref_idx=2, out="ef", out_idx=0),
                PhonemeGroup(ref="", out="gh", out_idx=1),
            ],
        ),
        (
            "abcd",
            "ab",
            ["abcd"],
            ["cd"],
            [
                PhonemeGroup(ref="abcd", ref_idx=0, out="cd", out_idx=0),
            ],
        ),
        (
            "cd",
            "abcd",
            ["cd"],
            ["abcd"],
            [
                PhonemeGroup(ref="cd", ref_idx=0, out="abcd", out_idx=0),
            ],
        ),
    ],
)
def test_segment_groups(ref_str, out_str, ref_groups, out_groups, ex_segments):
    # Create diff-match-patch object
    dmp_obj = dmp.diff_match_patch()

    # Calculate differences
    diffs = dmp_obj.diff_main(ref_str, out_str)
    print(diffs)
    out_segments = segment_groups(ref_groups, out_groups, diffs)
    for out_seg in out_segments:
        print(out_seg)
    assert out_segments == ex_segments
