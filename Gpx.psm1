#Requires -Version 2.0

function Remove-GpxWaypoints
{
<#
.Synopsis
Removes waypoints within a specified time range and adjusts subsequent waypoints by the offset.

.Description
You can use this cmdlet to remove waypoints from one or more track segments and adjust the time for any waypoints
after the end time to subtract the offset - effectively updating the track as if waypoints within the range of time
never occured (e.g. you took a break to look for a geocache along a trail).

.Parameter Path
The path to a GPX file. Wildcards are supported, but only the first resolve path will be used.

.Parameter LiteralPath
The path to a GPX file. Wildcards are not supported.

.Parameter Document
An XmlDocument object that contains the GPX data.

.Parameter Start
The starting date and time (local). The first waypoint after the start time is used for the real start time.

.Parameter End
The ending date and time (local). The last waypoint before the end time is used for the real end time.

.Parameter PassThru
The Document object is modified in memory. Setting the PassThru parameter returns it from the cmdlet anyway.

.Inputs
System.String
System.Xml.XmlDocument

.Outputs
System.Xml.XmlDocument
#>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param
    (
        [Parameter(ParameterSetName='Path', Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $Path,

        [Parameter(ParameterSetName='LiteralPath', Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias('PSPath')]
        [string] $LiteralPath,

        [Parameter(ParameterSetName='Document', Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [xml] $Document,

        [Parameter(Mandatory=$true, Position=1)]
        [datetime] $Start,

        [Parameter(Mandatory=$true, Position=2)]
        [datetime] $End,

        [Parameter(ParameterSetName='Document')]
        [switch] $PassThru
    )

    process
    {
        if ($PSCmdlet.ParameterSetName -eq 'Path')
        {
            $LiteralPath = resolve-path $Path | select-object -first 1
        }

        if ($LiteralPath)
        {
            $Document = get-content $LiteralPath
        }

        $Document.gpx.trk | select-object -expand trkseg | select-object -expand trkpt | foreach-object {

            [datetime] $time = $_.time

            if ($time -le $End)
            {
                if ($time -ge $Start)
                {
                    # Set the real start time.
                    if (-not $startpt)
                    {
                        [datetime] $startpt = $_.time
                    }

                    # Set the real end time and calculate offset.
                    [datetime] $endpt = $_.time
                    [timespan] $offset = $endpt - $startpt

                    # Remove the node.
                    $null = $_.ParentNode.RemoveChild($_)
                }
            }
            elseif ($offset)
            {
                # Adjust time and convert back to correct UTC format.
                $time = ($time - $offset).TouniversalTime()
                $_.time = $time.ToString('u') -replace ' ', 'T'
            }
        }

        if ($PSCmdlet.ParameterSetName -ne 'Document' -or $PassThru)
        {
            $Document
        }
    }
}
