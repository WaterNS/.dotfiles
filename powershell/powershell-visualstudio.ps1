# Powershell Visual Studio helpers (if available)

if (Check-Command vswhere) {
  if (!(Check-Command msbuild)) {
    $path = vswhere -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe | select-object -first 1
    if ($path) {
      Function AliasMSBuild {& $path $args}
      Set-Alias msbuild AliasMSBuild
    }
  }

  if (!(Check-Command vstest)) {
    $path = vswhere -latest -products * -requiresAny -property installationPath
    $path = join-path $path 'Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe'
    if ($path) {
      Function AliasVSTest {& $path $args}
      Set-Alias vstest AliasVSTest
    }
  }

  if (!(Check-Command vsDevCmd)) {
    $installationPath = vswhere -prerelease -latest -property installationPath
    if ($installationPath -and (test-path "$installationPath\Common7\Tools\vsdevcmd.bat")) {
      Function AliasVSDevCmd {
        echo "Setting/Entering Visual Studio Dev Environment variables"
        & "${env:COMSPEC}" /s /c "`"$installationPath\Common7\Tools\vsdevcmd.bat`" -no_logo && set" | foreach-object {
          $name, $value = $_ -split '=', 2
          set-content env:\"$name" $value
        }
      }
      Function AliasVSDevPS {
        $currentPath=$PWD
        echo "Entering Visual Studio Dev Environment (Powershell) ...`n"
        & $installationPath\Common7\Tools\Launch-VsDevShell.ps1
        Set-Location "$currentPath"
      }
      Set-Alias vsDevCmd AliasVSDevPS
    }
  }
}
