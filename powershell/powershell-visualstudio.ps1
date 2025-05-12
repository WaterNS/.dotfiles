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
      Function AliasVSTest {& $vsTestPath $args}
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
