Function updateGitRepo {
  param (
    $repoName=$($args[0]),
    $description=$($args[1]),
    $repoLocation=$($args[2])
  )

  $oldDir=$PWD
  ""
  "-Check updates: $repoName ($description)"
  cd "$repoLocation"
  git fetch

  if ((git rev-list --count master..origin/master) -gt 0) {
    Write-Host "--Updating $repoName $description repo " -NoNewline
    Write-Host "(from $(git rev-parse --short master) to " -NoNewline
    Write-Host "$(git rev-parse --short origin/master))" -NoNewline

    #HACK FIX for Azure Hosted Shell
    if ($env:ACC_CLOUD) {
      #Azure Shell like to inject crap into .bashrc. Hack fix for now
      "HACKFIX for AzureShell: Reverting 'posixshells/bash/.bashrc' to HEAD to allow updating..."
      git checkout HEAD -- posixshells/bash/.bashrc
    }


    git pull --quiet

    # Restart the init script if it self updated
    if ("$repoName" -eq "dotfiles") {
      cd $oldDir
      ""
      ""
      Invoke-Expression -Command ("$SCRIPTPATH $cmdArgs")
    }
  }

  cd $oldDir
}
function Check-Command {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$Binary
    )

    # Normal PowerShell resolution
    $cmd = Get-Command -Name $Name -ErrorAction SilentlyContinue

    if ($cmd) {
        if ($Binary) {
            # Only return true if it's an Application or ExternalScript
            if ($cmd.CommandType -in 'Application','ExternalScript') {
                return $true
            }
        }
        else {
            # Accept anything PowerShell resolves (Alias, Function, Cmdlet, Application, etc.)
            return $true
        }
    }

    # Windows-only: look in the “App Paths” registry
    if ($IsWindows) {
        # ShellExecute always searches for the full file name (e.g. devenv.exe)
        $exe = if ($Name -notmatch '\.') { "$Name.exe" } else { $Name }

        $appPaths = @(
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$exe",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$exe",
            # 32-bit view on 64-bit Windows (protects against WOW64 reflection edge cases)
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\$exe"
        )

        foreach ($key in $appPaths) {
            if (Test-Path $key) {
                return $true
            }
        }
    }

    return $false
}

Function Check-Installed($name, $type = "binary", $path) {
  switch ($type) {
    {$_ -like "*binary*"} { return Check-Command($name) }
    {$_ -like "*folder*" -and $path} { return [bool](Test-Path "$path") }
    {$_ -like "*folder*"} { return [bool](Test-Path "$HOME/.dotfiles/opt/bin/$name") }
    Default { Write-Warning "Check-Installed: Unexpected type ($type)"; return $false }
  }
}

Function Check-OS() {
  $os = "$([System.Environment]::OSVersion.Platform)"
  if ([System.Environment]::Is64bitProcess) {
    $os += " x64"
  } else {
    $os += " x32"
  }
  return "$os"
}

#Function to convert seconds to human friendly time format
Function seconds2time {

param (
 [parameter(Mandatory=$true,Position=0)]
 [ValidateNotNullOrEmpty()]
 [Alias('t')]
 [int]$time
)

 $t=$time
 $D=[math]::Truncate($t/60/60/24)
 $H=[math]::Truncate($t/60/60%24)
 $M=[math]::Truncate($t/60%60)
 $S=[math]::Truncate($t%60)

 $output=""

 #Print the days, if any
 if ($D -gt 0) {
   $output= $output + "$D day"; if ($D -gt 1) {$output= $output + "s"}
 }

 #Print the hours, if any
 if ($H -gt 0) {
   if ($D -gt 0) {$output= $output + ", "}
   if (($M -lt 1) -AND ($D -gt 0)) {$output= $output + "and "}
   $output= $output + "$H hour"; if ($H -gt 1) {$output= $output + "s"}
 }

 #Print the minutes, if any
 if ($M -gt 0) {
   if (($D -gt 0) -OR ($H -gt 0)) {$output= $output + ", "}
   if (($S -lt 1) -AND ($H -gt 0)) {$output= $output + "and "}
   $output= $output + "$M minute"; if ($M -gt 1) {$output= $output + "s"}
 }

 #Print the seconds, if any
 if ($S -gt 0) {
   if (($D -gt 0) -OR ($H -gt 0) -OR ($M -gt 0)) {$output= $output + ", "}
   if (($M -gt 0)) {$output= $output + "and "}
   $output= $output + "$S second"; if ($s -gt 1) {$output= $output + "s"}
 }

  if ($t -eq 0) {
    $output = "0 seconds"
  }

Write-Output $output
}

Function Test-InScript {
  if ( ((Get-PSCallStack).Command -like "*.ps1*") ) {
    return $true
  }

  return $false

}

Function Test-NotInScript {
  if (-NOT (Test-InScript)) {
    return $true
  }

  return $false

}

Function Test-IsNonInteractiveShell {
  if ([string]([Environment]::GetCommandLineArgs()) -like "*Start-EditorServices.ps1*") {
    # Hack:
    # Consider VS Code Powershell extension launched sessions as interactive
    return $false
  }
  if ([Environment]::UserInteractive) {
      foreach ($arg in [Environment]::GetCommandLineArgs()) {
          # Test each Arg for match of abbreviated '-NonInteractive' command.
          if (($arg -like '-NonI*') -OR ($arg -eq '-Command')) {
              return $true
          }
      }
  }

  return $false
}

Function find-string([String]$regex, $path) {
  if (!$path) {$path = "."}
  Get-ChildItem $path -file -recurse | Select-String -pattern ([Regex]::Escape("$regex")) | group path | select -ExpandProperty name
}

Function Get-URLs([parameter(ValueFromPipeline)][String]$Content) {
  (Select-String -AllMatches '(http[s]?)(:\/\/)([^\s,]+)(?=")' -Input $Content).Matches.Value
}

Function Powershell-FileDownload([String]$URL,$output) {
  $wc = new-object system.net.WebClient
  $wc.DownloadFile($URL,$output)
  $wc.Dispose()
}

Function gitRemoveOrphanBranches() {
  if (git rev-parse --git-dir 2> $null) {
    git checkout master;
    git remote update origin --prune;
    git branch -vv | Select-String -Pattern ": gone]" |
      ForEach-Object{ $_.toString().Trim().Split(" ")[0] } |
      ForEach-Object {git branch -D $_}
  } else {
    Write-Host "gitRemoveOrphanBranches:" -NoNewline -BackgroundColor Black -ForegroundColor White
    Write-Host " Error - Not a git repo" -ForegroundColor Yellow
  }
}

Function Add-EnvPath {
  #credit/ref/source: https://stackoverflow.com/a/34844707/7650275
  param(
      [Parameter(Mandatory=$true)]
      [string] $Path,

      [ValidateSet('Machine', 'User', 'Session')]
      [string] $Container = 'Session'
  )

  if ($Container -ne 'Session') {
      $containerMapping = @{
          Machine = [EnvironmentVariableTarget]::Machine
          User = [EnvironmentVariableTarget]::User
      }
      $containerType = $containerMapping[$Container]

      $persistedPaths = [Environment]::GetEnvironmentVariable('Path', $containerType) -split ';'
      if ($persistedPaths -notcontains $Path) {
          $persistedPaths = $persistedPaths + $Path | Where-Object { $_ }
          [Environment]::SetEnvironmentVariable('Path', $persistedPaths -join ';', $containerType)
      }
  }

  $envPaths = $env:Path -split ';'
  if ($envPaths -notcontains $Path) {
      $envPaths = $envPaths + $Path | Where-Object { $_ }
      $env:Path = $envPaths -join ';'
  }
}

Function pubkey {
  param(
      [Parameter(Mandatory=$false)]
      [string] $KeyName = "id_rsa"
  )

  if (Test-Path "$HOME/.ssh/$KeyName.pub") {
    Get-Content "$HOME/.ssh/$KeyName.pub";
    if (Check-Command "clip") {
      Get-Content "$HOME/.ssh/$KeyName.pub" | clip
      Write-Host "Copied to Clipboard!"
    }

  } else {
    Write-Host "Didn't find ~/.ssh/$KeyName.pub, aborting..."
  }
}

function foldertotal {
  param (
    [string]$Path = ".",
    [switch][Alias('r')]$rootDirOnly
  )

  $dollarRegex = '(?<=\$|-\$)\d+(\.\d{1,2})?'

  if (Test-Path -Path $Path) {
    if ($rootDirOnly) {
      $fileNames = Get-ChildItem -Path $Path -Name
    } else {
      $fileNames = Get-ChildItem -Path $Path -Name -Recurse
    }

    $sum = 0
    foreach ($fileName in $fileNames) {
      $matches = [regex]::Matches($fileName, $dollarRegex)
      foreach ($match in $matches) {
        if ($fileName.Contains("-$")) {
          $sum -= [decimal]::Parse($match.Value)
        }
        else {
          $sum += [decimal]::Parse($match.Value)
        }
      }
    }
    $sum = '{0:N2}' -f $sum
    return "`$$sum"
  }
  else {
    Write-Error "Path '$Path' not found."
  }
}

function hash256 {
  [CmdletBinding()]
  param(
      [Parameter(Mandatory = $true)]
      [string]$Path
  )

  if (-not (Test-Path -Path $Path)) {
      Write-Error "The path '$Path' does not exist."
      return
  }

  $item = Get-Item -Path $Path -ErrorAction Stop

  if ($item.PSIsContainer) {
      Write-Error "The path '$Path' is a directory, not a file."
      return
  }

  # Calculate the SHA256 hash
  $hash = Get-FileHash -Path $Path -Algorithm SHA256

  # Output the hash
  return $hash.Hash
}

function hashmd5 {
  [CmdletBinding()]
  param(
      [Parameter(Mandatory = $true)]
      [string]$Path
  )

  if (-not (Test-Path -Path $Path)) {
      Write-Error "The path '$Path' does not exist."
      return
  }

  $item = Get-Item -Path $Path -ErrorAction Stop

  if ($item.PSIsContainer) {
      Write-Error "The path '$Path' is a directory, not a file."
      return
  }

  # Calculate the MD5 hash
  $hash = Get-FileHash -Path $Path -Algorithm MD5

  # Output the hash
  return $hash.Hash
}

function ForceDelete {
  <#
      .SYNOPSIS
          Force-deletes a folder even when normal “access denied” errors occur.

      .DESCRIPTION
          • Tries a normal Remove-Item first.
          • If that fails, takes ownership, grants Administrators full control,
            clears read-only/hidden/system attributes, and tries again.
          • As a last resort, mirrors an empty temp folder over the target
            with ROBOCOPY /MIR (obliterates contents regardless of ACL),
            then removes the now-empty folder.

      .PARAMETER Path
          The folder you want to remove.

      .EXAMPLE
          Remove-FolderForce -Path "C:\LockedFolder"
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [Alias('FullName')]
    [string]$Path
  )

  process {
    if (-not (Test-Path -LiteralPath $Path)) {
      Write-Verbose "Path '$Path' does not exist—nothing to delete."
      return
    }

    try {
      # ---------- First, the easy way ----------
      Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
      Write-Verbose "Successfully removed '$Path' via Remove-Item."
      return
    }
    catch {
      Write-Warning "Standard removal failed: $($_.Exception.Message)"
    }

    # ---------- Escalation path ----------
    Write-Verbose "Taking ownership of '$Path' and resetting ACLs…"
    & takeown.exe /F $Path /A /R /D Y  | Out-Null   # /A = Administrators group owner
    & icacls.exe $Path /grant Administrators:F /T /C | Out-Null

    Write-Verbose "Clearing read-only/hidden/system attributes…"
    Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
    ForEach-Object { $_.Attributes = 'Normal' }
      (Get-Item -LiteralPath $Path).Attributes = 'Normal'

    try {
      Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
      Write-Verbose "Removed '$Path' after ownership reset."
      return
    }
    catch {
      Write-Warning "Removal still failing—invoking ROBOCOPY wipe."
    }

    # ---------- Last-ditch: ROBOCOPY mirror trick ----------
    $temp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid())
    New-Item -ItemType Directory -Path $temp | Out-Null
    & robocopy.exe $temp $Path /MIR /NJH /NJS /R:1 /W:0 | Out-Null
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue

    if (Test-Path -LiteralPath $Path) {
      throw "Unable to delete folder '$Path' even after escalated attempts."
    }
    else {
      Write-Verbose "Folder '$Path' successfully deleted via ROBOCOPY method."
    }
  }
}

function betterWhereIs {
<#
.SYNOPSIS
    “Where is … ?”  —  locate a command / executable / function / alias / variable
.DESCRIPTION
    For the supplied *name* the function returns **all** of the following that match:

      • **Executable**   - all full paths that Windows / PowerShell can launch
      • **Function**     - file in which the function is declared (or “<In-Memory>”)
      • **Alias**        - the command the alias expands to
      • **Variable**     - a preview of the variable's content (truncated for large values)

    Output is shaped for predictable default display:
      - Stable columns: **Name**, **Type**, **Info**
      - Category details are also included in: **Definition**, **DefinedIn**, **Paths**, **Preview**

    When nothing matches, a warning is emitted.

.PARAMETER Name
    The symbol to resolve. Accepts pipeline input.

.PARAMETER MaxVariableLength
    Maximum number of characters to show for variable preview (default = 120).

.EXAMPLE
    betterWhereIs git, PATH, Get-ChildItem, ls
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Name,

        [int]$MaxVariableLength = 120
    )

    begin {
        # Small helper to build a result object with a stable default view (Name,Type,Info)
        function New-BWIRecord {
            param(
                [string]$Name,
                [string]$Type,
                [string]$Info,
                [string]$Definition = $null,
                [string]$DefinedIn  = $null,
                [string[]]$Paths    = $null,
                [string]$Preview    = $null
            )

            $props = [ordered]@{
                Name       = $Name
                Type       = $Type
                Info       = $Info
                Definition = $Definition
                DefinedIn  = $DefinedIn
                Paths      = $Paths
                Preview    = $Preview
            }
            $obj = [pscustomobject]$props

            # Attach a per-object default display (Name, Type, Info) so mixed rows line up.
            try {
                $ddps   = New-Object System.Management.Automation.PSPropertySet `
                           'DefaultDisplayPropertySet', ([string[]]@('Name','Type','Info'))
                $coll   = New-Object 'System.Collections.ObjectModel.Collection[System.Management.Automation.PSMemberInfo]'
                $null   = $coll.Add($ddps)
                $psstd  = New-Object System.Management.Automation.PSMemberSet 'PSStandardMembers', $coll
                $null   = $obj.PSObject.Members.Add($psstd, $true)
            } catch {
                # Best-effort: safe to ignore in constrained environments
            }

            # Give it a friendly type name (useful if you later add format data)
            $null = $obj.PSObject.TypeNames.Insert(0, 'BetterWhereIs.Record')
            return $obj
        }
    }

    process {
        $foundAny = $false

        # 1. ---------- VARIABLE -------------------------------------------------
        if (Test-Path "variable:$Name") {
            $value = Get-Variable -Name $Name -ValueOnly
            $str   = if ($value -is [string]) { $value } else { $value | Out-String }
            if ($str.Length -gt $MaxVariableLength) { $str = $str.Substring(0, $MaxVariableLength) + ' …' }
            $str = $str.TrimEnd()

            New-BWIRecord -Name $Name -Type 'Variable' -Info $str -Preview $str
            $foundAny = $true
        }

        # 2. ---------- ALIAS ----------------------------------------------------
        $alias = Get-Alias -Name $Name -ErrorAction SilentlyContinue
        if ($alias) {
            New-BWIRecord -Name $Name -Type 'Alias' -Info $alias.Definition -Definition $alias.Definition
            $foundAny = $true
        }

        # 3. ---------- FUNCTION -------------------------------------------------
        $func = Get-Command -Name $Name -CommandType Function -ErrorAction SilentlyContinue
        if ($func) {
            $file = $func.ScriptBlock.File
            if ([string]::IsNullOrEmpty($file)) { $file = '<In-Memory>' }

            New-BWIRecord -Name $Name -Type 'Function' -Info $file -DefinedIn $file
            $foundAny = $true
        }

        # 4. ---------- EXECUTABLE / APPLICATION --------------------------------
        # Prefer Get-Command (cross-platform) but augment with Windows-specific
        # look-ups so the result matches what Start-Process / Run-dialogue sees.
        $paths = @()

        # 4a. On any host, ask the PowerShell resolver (include *all* matches)
        $apps = Get-Command -Name $Name -CommandType Application -All -ErrorAction SilentlyContinue
        if ($apps) { $paths += $apps.Source }

        if ($IsWindows) {
            # 4b. If where.exe is present, use it (same result Explorer's Run box gives)
            $whereExe = Get-Command where.exe -ErrorAction SilentlyContinue
            if ($whereExe) {
                $wOut = & where.exe $Name 2>$null
                if ($LASTEXITCODE -eq 0 -and $wOut) {
                    # filter out the "INFO: Could not find..." line if emitted
                    $paths += $wOut | Where-Object { $_ -and ($_ -notmatch '^\s*INFO:') }
                }
            }

            # 4c. App Paths registry (what ShellExecute consults when not on PATH)
            $exe = if ($Name -notmatch '\.') { "$Name.exe" } else { $Name }
            $reg = @(
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$exe",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$exe",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\$exe"
            )
            foreach ($k in $reg) {
                if (Test-Path $k) {
                    $default = (Get-ItemProperty $k).'(default)'
                    if ($default) { $paths += $default }
                }
            }
        }

        $paths = $paths | Where-Object { $_ } | Sort-Object -Unique
        if ($paths) {
            # Join for human-friendly Info; keep full array in Paths for scripting
            $info = ($paths -join [Environment]::NewLine)
            New-BWIRecord -Name $Name -Type 'Executable' -Info $info -Paths $paths
            $foundAny = $true
        }

        # 5. ---------- Nothing found -------------------------------------------
        if (-not $foundAny) {
            Write-Warning "No variable, function, alias or executable named '$Name' was found."
        }
    }
}

function findAll {
<#
.SYNOPSIS
  Search all filesystem drives for files whose names contain a given string.

.DESCRIPTION
  Recursively searches every FileSystem PSDrive (e.g., C:, D:, network mappings)
  and returns matches. By default, the function outputs a custom table with:
  Mode, LastWriteTime, Length, Name, FullPath.

  If you include wildcards (* or ?), they are used as-is; otherwise the function
  searches "*<text>*". Case-insensitive.

.PARAMETER Search
  The text to look for in file names. If you include wildcards (* or ?),
  they are used as-is; otherwise the function searches "*<text>*".

.PARAMETER IncludeDirectories
  Also return directories whose names match the search pattern.

.PARAMETER Extensions
  Optional list of file extensions (without dot) to restrict the results to.
  Example: -Extensions exe dll

.PARAMETER AsObjects
  Return full objects (FileInfo/DirectoryInfo) instead of the default table.
  Alias: -ShowDetails (back-compat with the earlier version).

.PARAMETER PathsOnly
  Return just the full path strings, one per line.

.EXAMPLE
  findAll msbuild
  # -> table with Mode, LastWriteTime, Length, Name, FullPath across all drives

.EXAMPLE
  findAll msbuild -Extensions exe
  # -> only files like MSBuild.exe

.EXAMPLE
  findAll log -IncludeDirectories
  # -> include folders named like "log"; Length will be blank for directories

.EXAMPLE
  findAll node -AsObjects
  # -> return FileInfo/DirectoryInfo objects for scripting/piping

.EXAMPLE
  findAll "*.config" -PathsOnly
  # -> return only full paths, one per line
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name','Pattern')]
        [string]$Search,

        [switch]$IncludeDirectories,

        [string[]]$Extensions,

        [switch]$AsObjects,

        [switch]$PathsOnly
    )

    # If no wildcard provided, search for "*<Search>*"
    $pattern = if ($Search -match '[\*\?\[\]]') { $Search } else { "*$Search*" }

    # Normalize extension filter (e.g., 'exe', 'dll'); compare case-insensitively
    $extSet = @()
    if ($Extensions) {
        $extSet = $Extensions | ForEach-Object { ($_ -replace '^\.', '').ToLowerInvariant() }
    }

    # Get all filesystem drives that are available
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { Test-Path $_.Root }

    $items = foreach ($drive in $drives) {
        try {
            # Files first
            $files = Get-ChildItem -LiteralPath $drive.Root -Recurse -Force -ErrorAction SilentlyContinue -File -Filter $pattern

            if ($extSet.Count -gt 0) {
                $files = $files | Where-Object {
                    $ext = $_.Extension.TrimStart('.').ToLowerInvariant()
                    $extSet -contains $ext
                }
            }

            $files

            # Optionally include directories
            if ($IncludeDirectories) {
                Get-ChildItem -LiteralPath $drive.Root -Recurse -Force -ErrorAction SilentlyContinue -Directory -Filter $pattern
            }
        }
        catch {
            # Ignore access/IO errors and continue scanning other drives
        }
    }

    # De-duplicate and return in a consistent order
    $items = $items | Sort-Object FullName -Unique

    if ($AsObjects) {
        # Return the actual FileInfo/DirectoryInfo objects (for scripting / further processing). Useful for piping
        return $items
    }
    elseif ($PathsOnly) {
        # Return just the full paths (compact, easy to pipe into other commands)
        return $items | Select-Object -ExpandProperty FullName
    }
    else {
        # Default: output shaped objects so the console renders a table with the requested columns.
        return $items | Select-Object `
            Mode, `
            LastWriteTime, `
            Length, `
            Name, `
            @{Name='FullPath';Expression={$_.FullName}} | Format-Table
    }
}
