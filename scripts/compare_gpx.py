#!/usr/bin/env python3
"""Compare two GPX tracks and report horizontal error statistics.

Examples (mirrors docs/HARDWARE_VALIDATION guidance):

  # Timestamp matching within 5 seconds (default)
  python3 scripts/compare_gpx.py baseline.gpx test.gpx

  # Tighter window plus CSV export for doc tables
  python3 scripts/compare_gpx.py --epsilon-sec 2 --csv logs/errors.csv \
      baseline.gpx test.gpx

  # Spatial nearest-neighbor comparison
  python3 scripts/compare_gpx.py --match nearest baseline.gpx test.gpx

Outputs summary stats (count, median, p90, max, mean) in meters and, if
requested, per-point CSV rows for deeper analysis.
"""

from __future__ import annotations

import argparse
import csv
import math
from bisect import bisect_left
from dataclasses import dataclass
from datetime import datetime, timezone
from statistics import mean
from typing import Iterable, List, Optional, Sequence, Tuple
import xml.etree.ElementTree as ET


R_EARTH_M = 6_371_000.0


@dataclass(frozen=True)
class TrackPoint:
    timestamp: Optional[datetime]
    seconds: Optional[float]
    lat: float
    lon: float


def _local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1] if "}" in tag else tag


def _parse_time(raw: Optional[str]) -> Optional[datetime]:
    if not raw:
        return None
    text = raw.strip()
    if not text:
        return None
    if text.endswith("Z") or text.endswith("z"):
        text = text[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(text)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    else:
        dt = dt.astimezone(timezone.utc)
    return dt


def parse_gpx(path: str) -> List[TrackPoint]:
    tree = ET.parse(path)
    root = tree.getroot()
    pts: List[TrackPoint] = []
    for trkpt in root.findall(".//{*}trkpt"):
        lat_s = trkpt.get("lat")
        lon_s = trkpt.get("lon")
        if lat_s is None or lon_s is None:
            continue
        try:
            lat = float(lat_s)
            lon = float(lon_s)
        except ValueError:
            continue
        timestamp: Optional[datetime] = None
        for child in trkpt:
            if _local(child.tag) == "time":
                timestamp = _parse_time(child.text)
                break
        seconds = timestamp.timestamp() if timestamp else None
        pts.append(TrackPoint(timestamp, seconds, lat, lon))
    return pts


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    lat1_r, lon1_r = math.radians(lat1), math.radians(lon1)
    lat2_r, lon2_r = math.radians(lat2), math.radians(lon2)
    dlat = lat2_r - lat1_r
    dlon = lon2_r - lon1_r
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(lat1_r) * math.cos(lat2_r) * math.sin(dlon / 2) ** 2)
    return R_EARTH_M * 2 * math.asin(min(1.0, math.sqrt(a)))


def match_by_time(
    base: Sequence[TrackPoint],
    test: Sequence[TrackPoint],
    epsilon: float,
) -> List[Tuple[TrackPoint, TrackPoint, float]]:
    base_t = [p for p in base if p.seconds is not None]
    test_t = [p for p in test if p.seconds is not None]
    if not base_t or not test_t:
        return []
    base_t.sort(key=lambda p: p.seconds)  # type: ignore[arg-type]
    test_t.sort(key=lambda p: p.seconds)  # type: ignore[arg-type]
    test_secs = [p.seconds for p in test_t]  # type: ignore[list-item]

    matches: List[Tuple[TrackPoint, TrackPoint, float]] = []
    for b in base_t:
        sec = b.seconds  # type: ignore[assignment]
        idx = bisect_left(test_secs, sec)
        candidates = []
        if idx < len(test_t):
            candidates.append(test_t[idx])
        if idx > 0:
            candidates.append(test_t[idx - 1])
        if not candidates:
            continue
        winner = min(candidates, key=lambda p: abs(p.seconds - sec))  # type: ignore[arg-type]
        if abs(winner.seconds - sec) <= epsilon:  # type: ignore[operator]
            dist = haversine_m(b.lat, b.lon, winner.lat, winner.lon)
            matches.append((b, winner, dist))
    return matches


def match_by_spatial(
    base: Sequence[TrackPoint],
    test: Sequence[TrackPoint],
) -> List[Tuple[TrackPoint, TrackPoint, float]]:
    if not base or not test:
        return []
    matches: List[Tuple[TrackPoint, TrackPoint, float]] = []
    test_rad = [(math.radians(p.lat), math.radians(p.lon), p) for p in test]
    for b in base:
        lat1 = math.radians(b.lat)
        lon1 = math.radians(b.lon)
        cos_lat1 = math.cos(lat1)
        best = float("inf")
        best_point: Optional[TrackPoint] = None
        for lat2, lon2, tp in test_rad:
            dlat = lat2 - lat1
            dlon = lon2 - lon1
            a = (math.sin(dlat / 2) ** 2 +
                 cos_lat1 * math.cos(lat2) * math.sin(dlon / 2) ** 2)
            dist = R_EARTH_M * 2 * math.asin(min(1.0, math.sqrt(a)))
            if dist < best:
                best = dist
                best_point = tp
        if best_point is not None:
            matches.append((b, best_point, best))
    return matches


def percentile(sorted_vals: Sequence[float], pct: float) -> float:
    if not sorted_vals:
        return float("nan")
    if pct <= 0:
        return sorted_vals[0]
    if pct >= 100:
        return sorted_vals[-1]
    rank = math.ceil(pct / 100 * len(sorted_vals)) - 1
    rank = min(max(rank, 0), len(sorted_vals) - 1)
    return sorted_vals[rank]


def summarize(distances: Sequence[float]) -> Tuple[int, float, float, float, float]:
    n = len(distances)
    if n == 0:
        nan = float("nan")
        return (0, nan, nan, nan, nan)
    vals = sorted(distances)
    mid = n // 2
    if n % 2:
        median = vals[mid]
    else:
        median = 0.5 * (vals[mid - 1] + vals[mid])
    return (
        n,
        median,
        percentile(vals, 90.0),
        vals[-1],
        mean(vals),
    )


def isoformat_z(dt: Optional[datetime]) -> str:
    if dt is None:
        return ""
    dt = dt.astimezone(timezone.utc).replace(microsecond=0)
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def write_csv(matches: Iterable[Tuple[TrackPoint, TrackPoint, float]], path: str) -> None:
    with open(path, "w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["timestamp", "lat", "lon", "error_m"])
        for base, _test, dist in matches:
            writer.writerow([
                isoformat_z(base.timestamp),
                f"{base.lat:.7f}",
                f"{base.lon:.7f}",
                f"{dist:.3f}",
            ])


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Compare two GPX tracks.")
    parser.add_argument("baseline", help="Baseline GPX file")
    parser.add_argument("test", help="Test GPX file")
    parser.add_argument(
        "--match",
        choices=["time", "nearest"],
        default="time",
        help="Matching strategy: time (default) or nearest spatial",
    )
    parser.add_argument(
        "--epsilon-sec",
        type=float,
        default=5.0,
        help="Max time delta for --match time (seconds)",
    )
    parser.add_argument(
        "--csv",
        dest="csv_path",
        help="Optional CSV output file",
    )
    args = parser.parse_args(argv)

    baseline = parse_gpx(args.baseline)
    test = parse_gpx(args.test)

    if args.match == "nearest":
        matches = match_by_spatial(baseline, test)
    else:
        matches = match_by_time(baseline, test, args.epsilon_sec)

    distances = [d for _b, _t, d in matches]
    count, median, p90, max_val, avg = summarize(distances)

    if count == 0:
        print("No matched points found.")
        return 1

    print(f"Matched: {count}")
    print(f"Median: {median:.2f} m")
    print(f"P90: {p90:.2f} m")
    print(f"Max: {max_val:.2f} m")
    print(f"Mean: {avg:.2f} m")

    if args.csv_path:
        write_csv(matches, args.csv_path)
        print(f"CSV written to {args.csv_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
