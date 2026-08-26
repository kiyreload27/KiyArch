[CmdletBinding()]
param(
    [string]$Iso = (Join-Path $PSScriptRoot '..\out\KiyArch-0.0.1-x86_64.iso'),
    [string]$Disk = (Join-Path $PSScriptRoot '..\.qemu\kiyarch-minimal.qcow2'),
    [switch]$Installed,
    [switch]$Reset
)

$ErrorActionPreference = 'Stop'
$RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Disk = [IO.Path]::GetFullPath($Disk)
$Vars = [IO.Path]::ChangeExtension($Disk, '.vars.fd')

function Find-Program([string[]]$Names) {
    foreach ($Name in $Names) {
        $Command = Get-Command $Name -ErrorAction SilentlyContinue
        if ($Command) { return $Command.Source }
    }
    throw "Required program not found: $($Names -join ', ')"
}

$Qemu = Find-Program @('qemu-system-x86_64.exe', 'qemu-system-x86_64')
$QemuImg = Find-Program @('qemu-img.exe', 'qemu-img')
$QemuDir = Split-Path $Qemu
$CodeCandidates = @(
    (Join-Path $QemuDir 'share\edk2-x86_64-code.fd'),
    (Join-Path $QemuDir 'share\edk2-i386-code.fd')
)
$VarsCandidates = @(
    (Join-Path $QemuDir 'share\edk2-x86_64-vars.fd'),
    (Join-Path $QemuDir 'share\edk2-i386-vars.fd')
)
$Code = $CodeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
$VarsTemplate = $VarsCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Code -or -not $VarsTemplate) {
    throw 'QEMU OVMF files were not found under its share directory.'
}

if ($Reset) {
    $Allowed = [IO.Path]::GetFullPath((Join-Path $RepoRoot '.qemu'))
    if (-not $Disk.StartsWith($Allowed, [StringComparison]::OrdinalIgnoreCase)) {
        throw '--Reset is restricted to the repository .qemu directory.'
    }
    Remove-Item -Force -ErrorAction SilentlyContinue $Disk, $Vars
}

New-Item -ItemType Directory -Force (Split-Path $Disk), (Split-Path $Vars) | Out-Null
if (-not (Test-Path $Disk)) {
    & $QemuImg create -f qcow2 $Disk 30G
    if ($LASTEXITCODE -ne 0) { throw 'qemu-img could not create the disposable disk.' }
}
if (-not (Test-Path $Vars)) { Copy-Item $VarsTemplate $Vars }

$Args = @(
    '-name', 'KiyArch-Minimal-UEFI',
    '-machine', 'q35',
    # Explicitly disable QEMU audio input/output, including microphone capture.
    '-audiodev', 'driver=none,id=noaudio',
    '-m', '4096',
    '-smp', '2',
    '-drive', "if=pflash,format=raw,readonly=on,file=$Code",
    '-drive', "if=pflash,format=raw,file=$Vars",
    '-drive', "if=virtio,format=qcow2,file=$Disk",
    '-nic', 'user,model=virtio-net-pci'
)

if (-not $Installed) {
    if (-not (Test-Path $Iso)) { throw "ISO not found: $Iso. Build it first." }
    $Args += @('-drive', "media=cdrom,readonly=on,format=raw,file=$Iso", '-boot', 'order=d')
}

if ($env:KIYARCH_QEMU_WHPX -eq '1') {
    $Args += @('-accel', 'whpx')
    Write-Host 'QEMU acceleration: WHPX'
} else {
    Write-Host 'QEMU acceleration: software; set KIYARCH_QEMU_WHPX=1 after enabling Windows Hypervisor Platform'
}

Write-Host "Disk: $Disk"
Write-Host "UEFI variables: $Vars"
Write-Host 'Stop QEMU after installation, then rerun with -Installed to boot without the ISO.'
& $Qemu @Args
exit $LASTEXITCODE
