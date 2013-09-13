#Requires -Version 2.0

function Edit-Gpx
{
<#
.Synopsis
Opens a GPX file and saves it after any modifications made in the pipeline.

.Description
Opens a GPX file and sends the document object through the pipeline for modification. After the pipeline is
complete, the document object is automatically saved to the same location from which it was opened.

.Parameter Path
The path to a GPX file. Wildcards are supported, but only the first resolved path will be used.

.Link
Open-Gpx
Save-Gpx
#>
    [CmdletBinding(DefaultParameterSetName='Path')]
    param
    (
        [Parameter(ParameterSetName='Path', Mandatory=$true, Position=0)]
        [string] $Path,

        [Parameter()]
        [ValidateSet('ASCII', 'BigEndianUnicode', 'Unicode', 'UTF32', 'UTF7', 'UTF8')]
        [string] $Encoding = 'UTF8',

        [Parameter()]
        [switch] $Indent
    )

    begin
    {
        $null = $PSBoundParameters.Remove('Encoding')
        $null = $PSBoundParameters.Remove('Indent')
        open-gpx @PSBoundParameters | tee-object -variable 'Document'
    }

    end
    {
        $PSBoundParameters.Add('Encoding', $Encoding)
        $PSBoundParameters.Add('Indent', $Indent)
        $Document | save-gpx @PSBoundParameters
    }
}

function Open-Gpx
{
<#
.Synopsis
Opens a GPX file.

.Description
Opens a GPX file and sends the document object through gtthe pipeline.

.Parameter Path
The GPX file to open. Wildcards are supported, but only the first path will be used.

.Outputs
System.Xml.XmlDocument

.Link
Edit-Gpx

.Link
Save-Gpx
#>
    [CmdletBinding(DefaultParameterSetName='Path')]
    param
    (
        [Parameter(ParameterSetName='Path', Mandatory=$true, Position=0)]
        [string] $Path
    )

    begin
    {
        $LiteralPath = resolve-path $Path | select-object -first 1

        write-verbose "Opening '$LiteralPath' as XML"
        [xml] (get-content -literalpath $LiteralPath)
    }
}

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
The path to a GPX file. Wildcards are supported, but only the first resolved path will be used.

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
            write-verbose "Opening '$LiteralPath' as XML"
            $Document = get-content -literalpath $LiteralPath
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

function Save-Gpx
{
<#
.Synopsis
Saves a GPX document object from the pipeline.

.Description
Saves a document object containing GPX data from the pipeline to the specified path.

.Parameter Document
The XML document object to save.

.Parameter Path
The path of the GPX file to save.

.Inputs
System.Xml.XmlDocument

.Link
Edit-Gpx

.Link
Open-Gpx
#>
    [CmdletBinding(DefaultParameterSetName='Document')]
    param
    (
        [Parameter(ParameterSetName='Document', Mandatory=$true, ValueFromPipeline=$true)]
        [xml] $Document,

        [Parameter(Mandatory=$true, Position=0)]
        [string] $Path,

        [Parameter()]
        [ValidateSet('ASCII', 'BigEndianUnicode', 'Unicode', 'UTF32', 'UTF7', 'UTF8')]
        [string] $Encoding = 'UTF8',

        [Parameter()]
        [switch] $Indent
    )

    end
    {
        $Settings = new-object System.Xml.XmlWriterSettings -property @{
            Encoding = [Text.Encoding]::$Encoding;
            Indent = $Indent;
            CloseOutput = $true;
        }

        $LiteralPath = [IO.Path]::Combine($PWD, $Path) | select-object -first 1
        $Writer = [Xml.XmlWriter]::Create($LiteralPath, $Settings)

        write-verbose "Saving XML to '$LiteralPath' with encoding '$($Settings.Encoding.EncodingName)'"
        $Document.Save($Writer)
        $Writer.Close()
    }
}
