param(
    [string]$IverilogExe = "C:\iverilog\bin\iverilog.exe",
    [string]$VvpExe = "C:\iverilog\bin\vvp.exe",
    [string]$PythonExe,
    [switch]$KeepArtifactsOnSuccess
)

$ErrorActionPreference = "Stop"

function Resolve-ToolCommand {
    param(
        [Parameter(Mandatory=$true)][string]$Requested,
        [Parameter(Mandatory=$true)][string]$ToolName
    )

    if ([string]::IsNullOrWhiteSpace($Requested)) {
        throw "$ToolName command is empty."
    }

    if (Test-Path $Requested) {
        return (Resolve-Path $Requested).Path
    }

    $cmd = Get-Command $Requested -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    throw "$ToolName not found: '$Requested'. Install it or pass an explicit path."
}

function Resolve-PythonExe {
    param([string]$RequestedPython)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPython)) {
        return Resolve-ToolCommand -Requested $RequestedPython -ToolName "Python"
    }

    $candidates = @()
    if ($IsWindows) {
        $candidates += @(
            ".\.venv-1\Scripts\python.exe",
            ".\.venv\Scripts\python.exe"
        )
    } else {
        $candidates += @(
            "./.venv-1/bin/python",
            "./.venv/bin/python"
        )
    }

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    return Resolve-ToolCommand -Requested "python" -ToolName "Python"
}

$iverilogCmd = Resolve-ToolCommand -Requested $IverilogExe -ToolName "iverilog"
$vvpCmd = Resolve-ToolCommand -Requested $VvpExe -ToolName "vvp"
$pythonCmd = Resolve-PythonExe -RequestedPython $PythonExe

$programs = @(
    @{ Name = "add";  Asm = "asm/add_two_numbers.asm"; Mem = "mem/add_two_numbers.mem" },
    @{ Name = "sum";  Asm = "asm/sum_1_to_5.asm";     Mem = "mem/sum_1_to_5.mem" },
    @{ Name = "calc"; Asm = "asm/calculator.asm";     Mem = "mem/calculator.mem" }
)

New-Item -ItemType Directory -Force "sim/logs" | Out-Null
New-Item -ItemType Directory -Force "sim/waves" | Out-Null

Write-Host "[1/3] Assembling programs..."
foreach ($p in $programs) {
    & $pythonCmd "assembler.py" $p.Asm $p.Mem
    if ($LASTEXITCODE -ne 0) {
        throw "Assembly failed for '$($p.Name)'"
    }
}

Write-Host "[2/3] Compiling testbench + CPU..."
& $iverilogCmd -g2012 -o "simv" "sim/tb_mini_cpu.v" "src/mini_cpu.v"
if ($LASTEXITCODE -ne 0) {
    throw "iverilog compilation failed"
}

Write-Host "[3/3] Running regression tests..."
$results = @()
foreach ($p in $programs) {
    Write-Host "Running TEST=$($p.Name)"
    $simOutput = & $vvpCmd "simv" "+TEST=$($p.Name)" 2>&1
    $exitCode = $LASTEXITCODE

    $simOutput | ForEach-Object { Write-Host $_ }
    $simOutput | Set-Content -Encoding ascii "sim/logs/$($p.Name).log"

    if ($exitCode -eq 0) {
        $results += [pscustomobject]@{ Test = $p.Name; Status = "PASS" }
        Write-Host "RESULT $($p.Name): PASS"
        if (Test-Path "sim/mini_cpu.vcd") {
            Remove-Item -Force "sim/mini_cpu.vcd"
        }
    } else {
        $results += [pscustomobject]@{ Test = $p.Name; Status = "FAIL" }
        Write-Host "RESULT $($p.Name): FAIL"
        if (Test-Path "sim/mini_cpu.vcd") {
            Copy-Item -Force "sim/mini_cpu.vcd" "sim/waves/$($p.Name).vcd"
            Remove-Item -Force "sim/mini_cpu.vcd"
        }

        Write-Host ""
        Write-Host "Regression summary (fail-fast):"
        foreach ($r in $results) {
            Write-Host (" - {0}: {1}" -f $r.Test, $r.Status)
        }

        if (Test-Path "simv") {
            Remove-Item -Force "simv"
        }

        exit 1
    }
}

Write-Host ""
Write-Host "Regression summary:"
foreach ($r in $results) {
    Write-Host (" - {0}: {1}" -f $r.Test, $r.Status)
}

if (Test-Path "simv") {
    Remove-Item -Force "simv"
}

if (-not $KeepArtifactsOnSuccess) {
    Get-ChildItem -Path "sim/logs" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path "sim/waves" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "Regression complete. All tests passed; temporary logs/waves cleaned."
} else {
    Write-Host "Regression complete. Logs in sim/logs/, waveforms in sim/waves/."
}
