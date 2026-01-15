# Powershell Visual Studio helpers (if available)

if (Check-Command vswhere) {
  if (!(Check-Command msbuild)) {
    $msBuildPath = vswhere -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe | select-object -first 1
    if ($msBuildPath) {
      Function AliasMSBuild {& $msBuildPath $args}
      Set-Alias msbuild AliasMSBuild
    }
  }

  if (!(Check-Command vstest)) {
    $vsTestPath = vswhere -latest -products * -requiresAny -property installationPath
    if ($vsTestPath) {
      $vsTestPath = join-path $vsTestPath 'Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe'
      Function AliasVSTest {
        if ($args.Count -gt 0) {
          & $vsTestPath @args
          return
        }

        Write-Host "No args supplied to vstest; running msbuild first..."
        & msbuild

        $buildConfig = $env:BuildConfiguration
        if ([string]::IsNullOrWhiteSpace($buildConfig)) {
          Write-Host "BuildConfiguration env var not set; searching all build folders."
        } else {
          Write-Host "Searching for test project outputs under the BuildConfiguration ($buildConfig) folder..."
        }

        $testDlls = @()
        $projectFiles = Get-ChildItem -Path . -Recurse -Filter *.csproj -File -ErrorAction SilentlyContinue
        foreach ($proj in $projectFiles) {
          $projContent = Get-Content -LiteralPath $proj.FullName -Raw -ErrorAction SilentlyContinue
          if ([string]::IsNullOrWhiteSpace($projContent)) {
            continue
          }

          $isTestProject =
            ($projContent -match '<IsTestProject>\s*true\s*</IsTestProject>') -or
            ($projContent -match 'Microsoft\.NET\.Test\.Sdk') -or
            ($projContent -match '<PackageReference[^>]*Include\s*=\s*"(xunit|nunit|MSTest\.TestAdapter|MSTest\.TestFramework)"')

          if (-not $isTestProject) {
            continue
          }

          $assemblyName = $null
          if ($projContent -match '<AssemblyName>\s*([^<]+)\s*</AssemblyName>') {
            $assemblyName = $Matches[1].Trim()
          }
          if ([string]::IsNullOrWhiteSpace($assemblyName)) {
            $assemblyName = [IO.Path]::GetFileNameWithoutExtension($proj.Name)
          }

          $binRoot = Join-Path $proj.DirectoryName 'bin'
          if (-not (Test-Path $binRoot)) {
            continue
          }

          $searchRoot = if ([string]::IsNullOrWhiteSpace($buildConfig)) { $binRoot } else { Join-Path $binRoot $buildConfig }
          $found = Get-ChildItem -Path $searchRoot -Recurse -Filter "$assemblyName.dll" -File -ErrorAction SilentlyContinue | Where-Object {
            $_.FullName -notmatch "\\obj\\"
          }

          if ($found) {
            $testDlls += $found
          }
        }

        if (-not $testDlls) {
          Write-Host "No test project outputs found; falling back to name-based search."
          $namePattern = '(?i)\.(tests?|unittests?|integrationtests?|functionaltests?|specs?)\.dll$'
          $testDlls = Get-ChildItem -Path . -Recurse -Filter *.dll -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match $namePattern -and $_.FullName -notmatch "\\obj\\" -and ([string]::IsNullOrWhiteSpace($buildConfig) -or $_.DirectoryName -match [regex]::Escape($buildConfig))
          }
        }

        $testDlls = $testDlls | Sort-Object -Property FullName -Unique
        if (-not $testDlls) {
          Write-Host "No test DLLs found."
          return
        }

        foreach ($dll in $testDlls) {
          Write-Host "Running tests in $($dll.FullName)"
          & $vsTestPath $dll.FullName
        }
      }
      Set-Alias vstest AliasVSTest
    }
  }

  if (!(Check-Command vsDevCmd)) {
    $vsDevCmdPath = vswhere -prerelease -latest -property installationPath
    if ($vsDevCmdPath -AND (Test-Path "$vsDevCmdPath\Common7\Tools\vsdevcmd.bat")){
      $vsDevCmdPath = "$vsDevCmdPath\Common7\Tools\"

      Function AliasVSDevCmd {
        echo "Setting/Entering Visual Studio Dev Environment variables"
        & "${env:COMSPEC}" /s /c "`"$vsDevCmdPath\vsdevcmd.bat`" -no_logo && set" | foreach-object {
          $name, $value = $_ -split '=', 2
          set-content env:\"$name" $value
        }
      }
      Function AliasVSDevPS {
        $currentPath=$PWD
        echo "Entering Visual Studio Dev Environment (Powershell) ...`n"
        & "$vsDevCmdPath\Launch-VsDevShell.ps1"
        Set-Location "$currentPath"
      }
      Set-Alias vsDevCmd AliasVSDevPS
    }
  }
}
