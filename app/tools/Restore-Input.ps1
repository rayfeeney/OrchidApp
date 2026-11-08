# Cloud Files placeholders are accepted only on the selected input path.
function Copy-OrchidRestoreInput([string]$Source, [string]$Destination) {
    $item = Get-Item -LiteralPath $Source -Force -ErrorAction Stop
    if ($item -isnot [IO.FileInfo] -or $item.Extension -ine '.zip' -or $item.FullName -notmatch '^[a-zA-Z]:\\[^:]+$') {
        throw 'Select a backup ZIP on a local Windows drive.'
    }
    if (-not ('OrchidRestoreInput' -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

public static class OrchidRestoreInput
{
    [StructLayout(LayoutKind.Sequential)]
    private struct AttributeTag
    {
        public uint Attributes;
        public uint Tag;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFile(string path, uint access, uint share,
        IntPtr security, uint disposition, uint flags, IntPtr template);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetFileInformationByHandleEx(SafeFileHandle file,
        int infoClass, out AttributeTag info, uint size);

    public static bool IsCloudTag(uint tag)
    {
        // IO_REPARSE_TAG_CLOUD and CLOUD_1 through CLOUD_F.
        return (tag & 0xFFFF0FFFu) == 0x9000001Au;
    }

    private static SafeFileHandle OpenChecked(string path, bool directory)
    {
        const uint openReparsePoint = 0x00200000;
        const uint backupSemantics = 0x02000000;
        var guard = CreateFile(path, 1, directory ? 3u : 1u, IntPtr.Zero, 3,
            openReparsePoint | (directory ? backupSemantics : 0u), IntPtr.Zero);
        try
        {
            if (guard.IsInvalid)
                throw new Win32Exception(Marshal.GetLastWin32Error());
            AttributeTag info;
            if (!GetFileInformationByHandleEx(guard, 9, out info, 8))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            if ((info.Attributes & (uint)FileAttributes.ReparsePoint) != 0 && !IsCloudTag(info.Tag))
                throw new IOException("The selected backup ZIP path has an unsupported reparse point.");
            return guard;
        }
        catch
        {
            guard.Dispose();
            throw;
        }
    }

    public static void Copy(string source, string destination)
    {
        var directories = new Stack<string>();
        for (var directory = new FileInfo(source).Directory; directory != null; directory = directory.Parent)
            directories.Push(directory.FullName);
        var guards = new Stack<SafeFileHandle>();
        try
        {
            // Check from the root down and deny renames while reopening the leaf for hydration.
            foreach (var directory in directories)
                guards.Push(OpenChecked(directory, true));
            guards.Push(OpenChecked(source, false));
            // A normal read asks Windows to hydrate any missing Cloud Files ranges.
            using (var input = File.Open(source, FileMode.Open, FileAccess.Read, FileShare.Read))
            using (var output = File.Open(destination, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                input.CopyTo(output);
        }
        finally
        {
            while (guards.Count != 0)
                guards.Pop().Dispose();
        }
    }
}
"@
    }
    try { [OrchidRestoreInput]::Copy($item.FullName, $Destination) }
    catch { throw "Could not stage the selected backup ZIP. If it is stored in OneDrive, make sure OneDrive is running and the file is available. $($_.Exception.GetBaseException().Message)" }
}
