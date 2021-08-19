  
Function Remove-VideoTags {

	<#
		.SYNOPSIS
			Remove Metadata Tags Title Comment and description from MP4 and MKV video files sets read only files to read

		.DESCRIPTION
            Uses TagLibSharp.dll to amend the tag information form video files, incorporates a switch to allow the title to be 
            set as the file name removing and ".".
            Source for TagLibSharp.dll https://www.nuget.org/api/v2/package/TagLibSharp 
            taglibsharp.2.2.0 (2).nupkg (Zip file)
            lib\netstandard2.0\TagLibSharp.dll


		.PARAMETER  VideoPath
			Path to video files
            Default script root

		.PARAMETER TagLibSharpPath
         Default script root
			
		.PARAMETER  Source
			The full path to the file to be copied. 
			If a local path is specified, it is converted to a UNC on the remote computer
			e.g. C:\Windows\Temp\Audit.log is automatically converted to \\Computer\C$\Windows\Temp\Audit.log
			
			
		.PARAMETER  SetTitle 
            (Switch)
			If present Sets the title name to be the file name
            Default False (Best For plex)
			
		.PARAMETER  VerboseOutput
            (Switch)
			If present Report on file activity, 
            Default will only output errors
            
		.PARAMETER  noRecurse
            (Switch)
			If present will not recurse through subdirectories 
            Default False
		.PARAMETER  UpdateTags
            (Switch)
			Script will report only unless this switch is present
            Default False
			
		.EXAMPLE
			PS Remove-VideoTags -VideoPath "c:\temp\mp4" -VerboseOutput -UpdateTags 
            

		.EXAMPLE
			PS C:\> Remove-VideoTags -VideoPath "c:\temp\mp4" -VerboseOutput -UpdateTags -noRecurse -SetTitle

			
		.NOTES
			Version: 1.0.0
            .mp4 files are a little akward and the remove all tags function does not work, the files can also be locked by Windows explorer.
            If mp4 tags are added through explorer they have to be removed manually


	#>

    Param (
        [parameter(position=0,valuefromPipeline=$true,valuefrompipelinebypropertyname=$true)]
        [string]$VideoPath=$PSScriptRoot,
        [parameter(valuefromPipeline=$true,valuefrompipelinebypropertyname=$true)]
        [string]$TagLibSharpPath="$PSScriptRoot\TagLibSharp.dll",
        [parameter(valuefromPipeline=$true,valuefrompipelinebypropertyname=$true)]
        [Switch]$SetTitle, # If Title specified on command line set Title to file name
        [parameter(valuefromPipeline=$true,valuefrompipelinebypropertyname=$true)]
        [Switch]$VerboseOutput,
        [parameter(valuefromPipeline=$true,valuefrompipelinebypropertyname=$true)]
        [Switch]$noRecurse,       
        [parameter(valuefromPipeline=$true,valuefrompipelinebypropertyname=$true)]
        [Switch]$UpdateTags
        )


    If ($VerboseOutput){$VerboseOutputPreference = 'Continue'}
    Else {$VerboseOutputPreference = 'SilentlyContinue'}

    #Load assembly from Dll
    [System.Reflection.Assembly]::LoadFrom(("$TagLibSharpPath"))
    #Get video files
    If ($noRecurse){$Videos=Get-ChildItem -Path "$VideoPath" -Include ('*.mkv', '*.mp4') }
    Else {$Videos=Get-ChildItem -Path "$VideoPath"  -Recurse -Include ('*.mkv', '*.mp4') }
    ForEach ($video in $Videos){ Write-Verbose  ">>> Getting file: $video"
        If($UpdateTags)
        {
                $videotag = $videotag = [TagLib.File]::Create(($video))
                $RemoveAlltags=$False
                If (!$SetTitle -and ($videotag.Tag.Comment.length) + ($videotag.Tag.Description.length) + ($videotag.Tag.Title.length)  -gt 0) {$RemoveAlltags=$True}
                ElseIf ($SetTitle -and ($videotag.Tag.Comment.length) + ($videotag.Tag.Description.length)  -gt 0){$RemoveAlltags=$True}

                  If($RemoveAlltags)
                  {
                    If((get-itemproperty $video).IsReadOnly){Write-Verbose  "Setting $video to read write";Set-ItemProperty $video -name IsReadOnly -value $false}
                    Write-Verbose "Remove all tags"
                    # commented lines don't seem to work for mp4 so set commentags to $null
                    $videotag.RemoveTags($videotag.TagTypes) 
                    Write-Verbose  "Saving File";$videotag.Save();$videotag.Dispose()
                    If ($($video.Extension) -like ".mp4")
                    {
                        Write-verbose "Extra check for MP4 files as somtimes clear does not work"
                        $videotag = $videotag = [TagLib.File]::Create(($video))
                        $RemoveAlltags=$False
                        If (!$SetTitle -and ($videotag.Tag.Comment.length) + ($videotag.Tag.Description.length) + ($videotag.Tag.Title.length)  -gt 0) {$RemoveAlltags=$True}
                        ElseIf ($SetTitle -and ($videotag.Tag.Comment.length) + ($videotag.Tag.Description.length)  -gt 0){$RemoveAlltags=$True}
                        If($RemoveAlltags)
                        {
                            Write-verbose "Comman tags not removed for MP4, try again removig common tags"
                            $videotag.Tag.Title=$Null
                            $videotag.Tag.Description=$Null
                            $videotag.Tag.Comment=$Null
                            $videotag.Save();$videotag.Dispose()
                        }
                    }
            
                }
                If($SetTitle)
                {
                    #start-sleep -Seconds 1
                    $videotag = $videotag = [TagLib.File]::Create(($video))
                    $Title=$($video.BaseName).Replace("."," ")
                    If ($($videotag.Tag.Title) -notlike $Title)
                    {
                       If((get-itemproperty $video).IsReadOnly){Write-Verbose  "Setting $video to read write";Set-ItemProperty $video -name IsReadOnly -value $false}
                       Write-Verbose  "Set title"
                       $videotag.Tag.Title=$Title
                       $videotag.Tag.Comment=$Title
                       Write-Verbose  "Saving File";$videotag.Save();$videotag.Dispose()
                    }
                }
            }

            $videotag = $videotag = [TagLib.File]::Create(($video))
            If ($SetTitle -and ((($videotag.Tag.Comment.length) + ($videotag.Tag.Description.length)  -gt 0) -or ($($videotag.Tag.Title) -notlike $Title)) )
            {
             Write-Host -ForegroundColor RED "Incorrect tag with title $video, Title=$($videotag.Tag.Title), Commment=$($videotag.Tag.Comment) ,  Description = $($videotag.Tag.Description)"
            }
            ElseIf (!$SetTitle -and ($videotag.Tag.Comment.length) + ($videotag.Tag.Description.length)  + ($videotag.Tag.Title.length) -gt 0)
            {
             Write-Host -ForegroundColor RED "Incorrect tag without title $video, Title=$($videotag.Tag.Title), Commment=$($videotag.Tag.Comment) ,  Description = $($videotag.Tag.Description)"
            }
            Else{Write-Verbose "Title=$($videotag.Tag.Title), Commment=$($videotag.Tag.Comment) ,  Description = $($videotag.Tag.Description)"}


    }
    If(!$UpdateTags){Write-Host -ForegroundColor Yellow "Reporting only no tags removed" }
    start-sleep -Seconds 1
    [gc]::Collect() 


}

Remove-VideoTags -VideoPath "c:\temp\mp4"  -UpdateTags 