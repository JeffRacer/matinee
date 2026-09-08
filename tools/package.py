"""Build the self-contained addon and test the actual ZIP in a clean project."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / 'addons/matinee'


def run_godot(godot, project, *arguments):
    result = subprocess.run(
        [godot, '--headless', '--path', str(project), *arguments],
        capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=90,
    )
    output = result.stdout + result.stderr
    if result.returncode or re.search(r'SCRIPT ERROR|Parse Error|^ERROR:', output, re.M):
        raise RuntimeError(output)
    return output


def build():
    version = re.search(r'version="([^"]+)"', (ADDON / 'plugin.cfg').read_text())[1]
    archive = ROOT / 'dist' / f'matinee-v{version}.zip'
    archive.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as package:
        for path in sorted(ADDON.rglob('*')):
            if not path.is_file() or '.godot' in path.parts or path.suffix == '.import':
                continue
            if path.suffix in ('.gd', '.tscn', '.tres'):
                for dependency in re.findall(r'res://[^"\s)]+', path.read_text(encoding='utf-8')):
                    if not dependency.startswith('res://addons/matinee/'):
                        # Resource paths belong to the host only when authored at runtime.
                        if dependency == 'res://':
                            continue
                        raise RuntimeError(f'External addon dependency in {path}: {dependency}')
                    if not (ROOT / dependency.removeprefix('res://')).exists():
                        raise RuntimeError(f'Missing dependency in {path}: {dependency}')
            info = zipfile.ZipInfo(path.relative_to(ROOT).as_posix(), (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            package.writestr(info, path.read_bytes())
    print(archive)
    return archive


def test(archive, godot):
    with tempfile.TemporaryDirectory(prefix='matinee-test-') as temporary:
        project = Path(temporary)
        with zipfile.ZipFile(archive) as package:
            package.extractall(project)
        shutil.copy(ROOT / 'tests/standalone_project/project.godot.template', project / 'project.godot')
        shutil.copy(ROOT / 'tests/standalone_project/standalone_smoke.gd', project / 'standalone_smoke.gd')
        shutil.copytree(ROOT / 'tests/fixtures', project / 'tests/fixtures')
        shutil.copytree(ROOT / 'examples', project / 'examples')
        for name in ('runtime_preview_test.gd', 'director_sequence_migration_test.gd'):
            shutil.copy(ROOT / 'tests' / name, project / 'tests' / name)
        print(run_godot(godot, project, '--editor', '--quit').splitlines()[0])
        for script in ('standalone_smoke.gd', 'tests/runtime_preview_test.gd', 'tests/director_sequence_migration_test.gd'):
            output = run_godot(godot, project, '--script', 'res://' + script)
            if 'passed' not in output.lower():
                raise RuntimeError(f'{script} did not report success:\n{output}')
            print(output.strip())


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--test', action='store_true')
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    archive = build()
    if args.test:
        test(archive, args.godot)
