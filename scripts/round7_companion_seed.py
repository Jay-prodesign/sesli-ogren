#!/usr/bin/env python3
"""Generate deterministic non-final geometry control seeds for Round 7 Companion production.

These SVGs are NOT finalist art. They exist only to constrain the image model's
geometry/topology before materialization.
"""

from __future__ import annotations

import argparse
from pathlib import Path

CANVAS = 1024
BG = "#F5F0E8"
DARK = "#161616"
MID = "#777777"
LIGHT = "#C9C2B8"

# Candidate-specific deterministic control geometry.
# Each variant changes only a small structural parameter while preserving identity.
D_PATHS = {
    1: [
        ("M 270 510 C 250 300, 470 210, 610 330 C 760 470, 680 700, 500 735 C 335 765, 235 650, 270 510", 128, MID),
        ("M 390 300 C 590 180, 785 335, 735 525 C 690 700, 470 805, 325 660 C 205 540, 255 370, 390 300", 112, DARK),
        ("M 414 335 C 520 275, 625 295, 688 382", 38, BG),
        ("M 345 650 C 430 715, 555 705, 635 625", 38, BG),
    ],
    2: [
        ("M 250 535 C 220 335, 420 205, 595 305 C 785 415, 735 665, 560 735 C 375 810, 230 705, 250 535", 132, MID),
        ("M 390 285 C 570 170, 775 300, 770 500 C 765 675, 585 790, 405 725 C 235 665, 205 465, 390 285", 108, DARK),
        ("M 388 352 C 492 300, 602 310, 682 390", 40, BG),
        ("M 370 650 C 455 700, 560 688, 640 610", 40, BG),
    ],
    3: [
        ("M 300 520 C 285 300, 495 215, 635 360 C 760 490, 665 715, 485 735 C 330 755, 250 650, 300 520", 118, MID),
        ("M 395 305 C 590 195, 765 360, 705 545 C 640 735, 420 790, 300 620 C 205 485, 270 355, 395 305", 118, DARK),
        ("M 425 350 C 520 300, 610 330, 665 410", 36, BG),
        ("M 330 620 C 425 690, 540 700, 620 630", 36, BG),
    ],
}

E_SHAPES = {
    1: [
        "M 330 770 L 485 220 L 690 705 L 545 650 L 470 430 L 405 705 Z",
        "M 515 245 L 730 520 L 610 560 L 500 430 Z",
        "M 430 620 L 585 535 L 650 650 L 505 740 Z",
    ],
    2: [
        "M 315 760 L 470 210 L 705 690 L 555 660 L 475 435 L 390 700 Z",
        "M 500 245 L 745 500 L 620 555 L 500 420 Z",
        "M 425 625 L 575 520 L 655 635 L 510 735 Z",
    ],
    3: [
        "M 350 780 L 505 230 L 700 720 L 560 675 L 500 470 L 425 720 Z",
        "M 530 255 L 725 510 L 610 565 L 515 445 Z",
        "M 445 640 L 595 550 L 665 665 L 525 755 Z",
    ],
}


def _header(candidate: str, variant: int) -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" height="{CANVAS}" '
        f'viewBox="0 0 {CANVAS} {CANVAS}">\n'
        f'  <metadata>Round 7 geometry control seed; candidate={candidate}; variant={variant}; non-final-art</metadata>\n'
        f'  <rect width="{CANVAS}" height="{CANVAS}" fill="{BG}"/>\n'
        f'  <g id="candidate-{candidate.lower()}-variant-{variant}">\n'
    )


def seed_svg(candidate: str, variant: int) -> str:
    if candidate not in {"D", "E"}:
        raise ValueError("candidate must be D or E")
    if variant not in {1, 2, 3}:
        raise ValueError("variant must be 1, 2, or 3")

    out = [_header(candidate, variant)]
    if candidate == "D":
        for d, width, color in D_PATHS[variant]:
            out.append(
                f'    <path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" '
                'stroke-linecap="round" stroke-linejoin="round"/>\n'
            )
    else:
        shapes = E_SHAPES[variant]
        fills = (MID, DARK, LIGHT)
        for points, color in zip(shapes, fills):
            out.append(f'    <path d="{points}" fill="{color}" stroke="none"/>\n')
    out.append("  </g>\n</svg>\n")
    return "".join(out)


def write_seed(candidate: str, variant: int, output: Path) -> Path:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(seed_svg(candidate, variant), encoding="utf-8")
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", choices=["D", "E"], required=True)
    parser.add_argument("--variant", type=int, choices=[1, 2, 3])
    parser.add_argument("--out", type=Path)
    parser.add_argument("--all", action="store_true", help="Write all three variants to --out directory.")
    args = parser.parse_args()

    if args.all:
        if args.out is None:
            raise SystemExit("--all requires --out directory")
        for variant in (1, 2, 3):
            path = args.out / f"round7_{args.candidate.lower()}_seed_v{variant}.svg"
            write_seed(args.candidate, variant, path)
            print(path)
        return 0

    if args.variant is None or args.out is None:
        raise SystemExit("single-seed mode requires --variant and --out")
    print(write_seed(args.candidate, args.variant, args.out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
