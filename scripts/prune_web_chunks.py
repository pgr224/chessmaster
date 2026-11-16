#!/usr/bin/env python3
"""Remove stale deferred chunks copied from Flutter's incremental build cache."""
from pathlib import Path
import re
import sys


def prune(build_dir: Path) -> None:
    main = build_dir / 'main.dart.js'
    if not main.is_file():
        raise SystemExit(f'Release bundle missing: {main}')
    referenced = set(re.findall(r'main\.dart\.js_\d+\.part\.js', main.read_text()))
    missing = sorted(name for name in referenced if not (build_dir / name).is_file())
    if missing:
        raise SystemExit(f'Referenced deferred chunks missing: {missing}')
    obsolete = [path for path in build_dir.glob('main.dart.js_*.part.js')
                if path.name not in referenced]
    saved = sum(path.stat().st_size for path in obsolete)
    for path in obsolete:
        path.unlink()
    print(f'Retained {len(referenced)} deferred chunks; removed {len(obsolete)} stale chunks ({saved:,} bytes).')


if __name__ == '__main__':
    prune(Path(sys.argv[1]) if len(sys.argv) > 1
          else Path(__file__).resolve().parents[1] / 'app' / 'build' / 'web')
