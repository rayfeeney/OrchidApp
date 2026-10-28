"""Safe inventory checks for the complete Linux package produced in this job."""
from pathlib import PurePosixPath
import stat


def validate_package(archive):
    members=archive.infolist()
    if len(members)>15000 or sum(i.file_size for i in members)>2*1024**3:
        raise ValueError('Package resource limit')
    seen=set()
    for item in members:
        name=item.filename.rstrip('/') if item.is_dir() else item.filename
        path=PurePosixPath(name)
        kind=stat.S_IFMT(item.external_attr>>16)
        if ('\\' in name or ':' in name or path.is_absolute() or not path.parts or
                any(p in ('','.','..') or p.startswith('.env') for p in name.split('/')) or
                path.parts[0]!='OrchidApp' or name in seen or
                kind not in (0,stat.S_IFREG,stat.S_IFDIR)):
            raise ValueError('Unsafe package member')
        seen.add(name)
    required={'OrchidApp/app/OrchidApp.Web.dll','OrchidApp/infrastructure/backups/orchid_backup.py'}
    if not required.issubset(seen):raise ValueError('Complete Linux package required')
    return len(members)
