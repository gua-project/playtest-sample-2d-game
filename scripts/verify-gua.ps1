# Offline inspection of both actual Godot DLLs. Ports/env cannot grant compiled remote access.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$lock=Get-Content "$PSScriptRoot/gua-dependency.json" -Raw | ConvertFrom-Json
if (!('GuildArtifactIdentity' -as [type])) {
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class GuildArtifactIdentity {
  [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int CopyJson(IntPtr output, int size);
  public static string Read(string path) {
    var dll=NativeLibrary.Load(path);
    try {
      var copy=Marshal.GetDelegateForFunctionPointer<CopyJson>(NativeLibrary.GetExport(dll,"gua_godot_copy_build_info_json"));
      int size=copy(IntPtr.Zero,0);
      if(size<=0 || size>65536) throw new InvalidOperationException("Invalid identity size");
      var data=Marshal.AllocHGlobal(size);
      try { if(copy(data,size)!=size) throw new InvalidOperationException("Identity changed"); return Marshal.PtrToStringUTF8(data); }
      finally { Marshal.FreeHGlobal(data); }
    } finally { NativeLibrary.Free(dll); }
  }
}
"@
}
$records=@(foreach($configuration in 'debug','release') {
  $file=Join-Path $root "addons/gua/bin/gua_godot.windows.$configuration.x86_64.dll"
  $hash=(Get-FileHash $file).Hash
  if ($hash -ine $lock.windowsDllSha256.$configuration) { throw "Gua DLL hash mismatch: $file" }
  $info=[GuildArtifactIdentity]::Read($file) | ConvertFrom-Json
  if ($info.schemaVersion -ne 1 -or $info.flavor -ne $lock.flavor -or $info.remoteEnabled -ne $true -or
      $info.remotePermissionCeiling -ne $lock.remotePermissionCeiling -or $info.sourceCommit -ne $lock.sourceCommit -or
      $info.buildId -ne $lock.sourceCommit -or $info.configuration -ine $configuration -or 'websocket' -notin $info.transports) { throw "Gua identity mismatch: $file $($info | ConvertTo-Json -Compress)" }
  [ordered]@{file="gua_godot.windows.$configuration.x86_64.dll";sha256=(Get-FileHash $file).Hash;buildInfo=$info}
})
[ordered]@{dependency=$lock;binaries=$records} | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $root '.deps/gua-verified.json')
Write-Output 'Gua Development remote ON / Debug ceiling: both DLL identities verified offline'
