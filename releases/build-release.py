"""Build and verify a CurseForge-ready addon ZIP from one immutable Git commit."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import io
import json
import re
import subprocess
import zipfile
from PIL import Image

repository = Path(__file__).resolve().parents[1]
version = '0.2.1'


def git(*arguments):
    return subprocess.run(['git', '-C', str(repository), *arguments], check=True, capture_output=True).stdout


revision = git('rev-parse', 'HEAD').decode().strip()
output = Path(__file__).resolve().parent / ('v' + version)
output.mkdir(parents=True, exist_ok=True)

paths = ['ForeverProfiles.toc', 'Init.lua', 'Graphics.lua', 'Profiles.lua', 'UI.lua', 'Core.lua', 'Bindings.xml', 'Media/Logo.tga']
files = {path: git('show', revision + ':' + path) for path in paths}
toc = files['ForeverProfiles.toc'].decode('utf-8')
assert re.search(r'^## Version:\s*' + re.escape(version) + r'\s*$', toc, re.MULTILINE)
assert re.search(r'^## Interface:\s*16001\s*$', toc, re.MULTILINE)
assert ('F.version = "' + version + '"') in files['Init.lua'].decode('utf-8')
assert r'## IconTexture: Interface\AddOns\ForeverProfiles\Media\Logo' in toc
listed = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith('#')]
assert all(path in files for path in listed)
assert 'Bindings.xml' not in listed
assert files['Bindings.xml'].decode('utf-8').lstrip().startswith('<Bindings>')
with Image.open(io.BytesIO(files['Media/Logo.tga'])) as icon:
    assert icon.mode == 'RGBA' and icon.size == (64, 64)
    icon.verify()

timestamp = int(git('show', '-s', '--format=%ct', revision).decode().strip())
stamp = datetime.fromtimestamp(timestamp, timezone.utc).timetuple()[:6]
archive = output / ('ForeverProfiles-' + version + '.zip')
with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zipped:
    for path in paths:
        info = zipfile.ZipInfo('ForeverProfiles/' + path, date_time=stamp)
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        zipped.writestr(info, files[path], compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)

with zipfile.ZipFile(archive) as zipped:
    assert zipped.testzip() is None
    assert set(zipped.namelist()) == {'ForeverProfiles/' + path for path in paths}
    assert all(name.split('/')[0] == 'ForeverProfiles' and '..' not in name.split('/') for name in zipped.namelist())
    for path, content in files.items():
        assert zipped.read('ForeverProfiles/' + path) == content

digest = hashlib.sha256(archive.read_bytes()).hexdigest()
(output / (archive.name + '.sha256')).write_text(digest + '  ' + archive.name + '\n', encoding='ascii')
metadata = {'version': version, 'revision': revision, 'archive': str(archive), 'size': archive.stat().st_size, 'sha256': digest, 'files': ['ForeverProfiles/' + path for path in paths]}
(output / 'manifest.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
print(json.dumps(metadata, indent=2))
