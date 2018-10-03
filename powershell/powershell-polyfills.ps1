#Powershell Polyfills
#
# Recreate functionality of some bash commands in Powershell (e.g. touch)


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

Function Powershell-Touch
{

  If (($MyInvocation.InvocationName -eq "touch") -AND (Test-NotInScript)) {
    "------"
    "touch: Using non-Linux `'touch`' - this is my powershell polyfill of `'touch`'"
    "------"
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
    "---------------------------------------------------------------------------"
    "grep: Using non-Linux `'grep`' - this is my powershell polyfill of `'grep`'"
    "---------------------------------------------------------------------------"
  }

  $searchterm = $args[0]
  $searchfile = $args[1]
  
  if($searchfile -eq $null) {
      throw "No filename supplied"
  }

  if(Test-Path $searchfile -PathType Leaf)
  {
    Select-String $searchterm $searchfile -ca | select -exp line
  } else {
    "File: $searchfile - doesn't exist"
  }

}
Set-Alias grep Powershell-VeryBasicGrep

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
    "---------------------------------------------------------------------------"
    "tail: Using non-Linux `'tail`' - this is my powershell polyfill of `'tail`'"
    "---------------------------------------------------------------------------"
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
    "------"
    "head: Using non-Linux `'head`' - this is my powershell polyfill of `'head`'"
    "------"
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

