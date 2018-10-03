﻿#Function to convert seconds to human friendly time format 
Function seconds2time {

param (
 [parameter(Mandatory=$true,Position=0)]
 [ValidateNotNullOrEmpty()]
 [Alias('t')]
 [int]$time
)

 $t=$time
 $D=[int]($t/60/60/24)
 $H=[int]($t/60/60%24)
 $M=[int]($t/60%60)
 $S=[int]($t%60)

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

# Function: Update git repo (if needed)
Function updategitrepo {
	
param (
  $reponame=$($args[0]),
  $description=$($args[1]),
  $repolocation=$($args[2])
)

$olddir=$PWD

echo ""
echo "-Check updates: $reponame ($description)"
cd "$repolocation"
git fetch

if ("$(git rev-parse master)" -ne "$(git rev-parse origin/master)") {
  echo -n "--Updating $reponame $description repo "
  echo -n "(from $(git rev-parse --short master) to "
  echo -n "$(git rev-parse --short origin/master))"
  git pull --quiet
  
  # Restart the init script if it self updated
  if ("$reponame" -eq "dotfiles") {
    cd $olddir
	echo ""
	echo ""
	exec $SCRIPTPATH -u;
  }
}

cd $olddir

}