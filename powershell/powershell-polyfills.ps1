#Powershell Polyfills
#
# Recreate functionality of some bash commands in Powershell (e.g. touch)

. $PSScriptRoot\powershell-functions.ps1

Function Powershell-Touch
{

  If (($MyInvocation.InvocationName -eq "touch") -AND (Test-NotInScript)) {
    Write-Warning "------------------------------------------------------------------------------"
    Write-Warning "touch: Using non-Linux `'touch`' - this is my powershell polyfill of `'touch`'"
    Write-Warning "------------------------------------------------------------------------------"
  }

  $file = $args[0]
  if($file -eq $null) {
      throw "No filename supplied"
  }

  if(Test-Path $file)
  {
      (Get-ChildItem $file).LastWriteTime = Get-Date
  }
  else
  {
      (New-Item $file > $null)
  }

}
Set-Alias touch Powershell-Touch


Function Powershell-VeryBasicGrep
{

  If (($MyInvocation.InvocationName -eq "grep") -AND (Test-NotInScript)) {
    Write-Warning "---------------------------------------------------------------------------"
    Write-Warning "grep: Using non-Linux `'grep`' - this is my powershell polyfill of `'grep`'"
    Write-Warning "---------------------------------------------------------------------------"
  }

  $searchTerm = $args[0]
  $searchFile = $args[1]

  if($searchFile -eq $null) {
      throw "No filename supplied"
  }

  if(Test-Path $searchFile -PathType Leaf)
  {
    Select-String $searchTerm $searchFile -ca | select -exp line
  } else {
    "File: $searchFile - doesn't exist"
  }

}
#Set-Alias grep Powershell-VeryBasicGrep

Function Powershell-Tail {
<#
 .SYNOPSIS
 Get the last x lines of a text file

 .DESCRIPTION
 Get the last x lines of a text file

 .PARAMETER Path
 Path to the text file

.PARAMETER Lines (or -n)
 Number of lines to retrieve

.INPUTS
 IO.FileInfo
 System.Int

.OUTPUTS
 System.String

.EXAMPLE
 PS> Get-ContentTail -Path c:\server.log -Lines 10

.EXAMPLE
 PS> Get-ContentTail -Path c:\server.log -Lines 10 -Follow

#>
[CmdletBinding()][OutputType('System.String')]

Param
 (

[parameter(Mandatory=$true,Position=0)]
 [ValidateNotNullOrEmpty()]
 [IO.FileInfo]$Path,

 [parameter(Mandatory=$false,Position=1)]
 [ValidateNotNullOrEmpty()]
 [Alias('n')]
 [Int]$Lines,

[parameter(Mandatory=$false,Position=2)]
 [Switch]$Follow
 )

   If (($MyInvocation.InvocationName -eq "tail") -AND (Test-NotInScript)) {
    Write-Warning "---------------------------------------------------------------------------"
    Write-Warning "tail: Using non-Linux `'tail`' - this is my powershell polyfill of `'tail`'"
    Write-Warning "---------------------------------------------------------------------------"
  }

 try {

if ($PSBoundParameters.ContainsKey('Follow')){
  Get-Content -Path $Path -Tail $Lines -Wait
} elseif ($Lines) {
    Get-Content -Path $Path -Tail $Lines
} else {
    Get-Content -Path $Path
}

}
 catch [Exception]{

 throw "Unable to get the last x lines of a text file....."
 }
 }
Set-Alias tail Powershell-Tail

Function Powershell-Head
{
 Param (

   [parameter(Mandatory=$true,Position=0)]
   [ValidateNotNullOrEmpty()]
   $file,

   [parameter(Mandatory=$false,Position=1)]
   [ValidateNotNullOrEmpty()]
   [Alias('n')]
   [Int]$lines
 )


  If (($MyInvocation.InvocationName -eq "head") -AND (Test-NotInScript)) {
    Write-Warning "----------------------------------------------------------------------------"
    Write-Warning "head: Using non-Linux `'head`' - this is my powershell polyfill of `'head`'"
    Write-Warning "----------------------------------------------------------------------------"
  }


  if($file -eq $null) {
      throw "No filename supplied"
  }

  If ($Lines) {
      Get-Content -TotalCount $Lines $file
  } else {
      Get-Content -Path $file | select -First 10
  }

}
Set-Alias head Powershell-Head

#------------------------------------------------------------------
# Polyfill: $IsWindows   (for Windows PowerShell 5.1 / PS Core ≤ 6)
#------------------------------------------------------------------
if (-not (Test-Path 'variable:\IsWindows')) {
    # ---------- Detect the platform ----------
    # Preferred API (available on any system with recent .NET):
    $isWin = $false
    try {
        $isWin = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
                     [System.Runtime.InteropServices.OSPlatform]::Windows )
    } catch {
        # Fallbacks that always work in WinPS 5.1
        $isWin = ($env:OS -eq 'Windows_NT') -or
                 ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)
    }

    # ---------- Publish the variable ----------
    # Make it global and read-only so later code can rely on it.
    Set-Variable -Name IsWindows -Value $isWin -Scope Global -Option ReadOnly
}
