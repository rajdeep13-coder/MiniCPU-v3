param(
    [string]$IverilogExe = "C:\iverilog\bin\iverilog.exe",
    [string]$VvpExe = "C:\iverilog\bin\vvp.exe"
)

$ErrorActionPreference = "Stop"

function Resolve-PythonExe {
    $candidates = @(
        ".\.venv-1\Scripts\python.exe",
        ".\.venv\Scripts\python.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCmd) {
        return $pythonCmd.Source
    }

    throw "Python executable not found. Activate a venv or install Python."
}

if (!(Test-Path $IverilogExe)) {
    throw "iverilog not found at '$IverilogExe'. Install Icarus Verilog or pass -IverilogExe."
}

if (!(Test-Path $VvpExe)) {
    throw "vvp not found at '$VvpExe'. Install Icarus Verilog or pass -VvpExe."
}

$pythonExe = Resolve-PythonExe

$programs = @(
    @{ Name = "add";  Asm = "asm/add_two_numbers.asm"; Mem = "mem/add_two_numbers.mem" },
    @{ Name = "sum";  Asm = "asm/sum_1_to_5.asm";     Mem = "mem/sum_1_to_5.mem" },
    @{ Name = "calc"; Asm = "asm/calculator.asm";     Mem = "mem/calculator.mem" }
)

New-Item -ItemType Directory -Force "sim/logs" | Out-Null
New-Item -ItemType Directory -Force "sim/waves" | Out-Null

Write-Host "[1/3] Assembling programs..."
foreach ($p in $programs) {
    & $pythonExe "assembler.py" $p.Asm $p.Mem
}

Write-Host "[2/3] Compiling testbench + CPU..."
& $IverilogExe -g2012 -o "simv" "sim/tb_mini_cpu.v" "src/mini_cpu.v"

Write-Host "[3/3] Running regression tests..."
foreach ($p in $programs) {
    Write-Host "Running TEST=$($p.Name)"
    $simOutput = & $VvpExe "simv" "+TEST=$($p.Name)"
    $simOutput | ForEach-Object { Write-Host $_ }
    $simOutput | Set-Content -Encoding ascii "sim/logs/$($p.Name).log"
    Copy-Item -Force "sim/mini_cpu.vcd" "sim/waves/$($p.Name).vcd"
}

if (Test-Path "sim/mini_cpu.vcd") {
    Remove-Item -Force "sim/mini_cpu.vcd"
}

if (Test-Path "simv") {
    Remove-Item -Force "simv"
}

Write-Host "Regression complete. Logs in sim/logs/, waveforms in sim/waves/."
