# Function to log detailed information
function Log-Details {
    param (
        [string]$message
    )
    $logFile = "response_log.txt"
    Add-Content -Path $logFile -Value $message
}

# Function to resolve the URI to an IP address
function Resolve-UriToIpAddress {
    param (
        [string]$uri
    )
    try {
        $hostname = (New-Object System.Uri $uri).Host
        $ipAddresses = [System.Net.Dns]::GetHostAddresses($hostname) | ForEach-Object { $_.IPAddressToString }
        return $ipAddresses
    } catch {
        Write-Output "Error: Unable to resolve IP address for $uri"
        return @()
    }
}

# Enhanced function to get HTTP response details with logging
function Get-HttpResponse {
    param (
        [string]$url,
        [string]$ip,
        [int]$requestNumber
    )
    try {
        $start = Get-Date
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
        $end = Get-Date
        $timeTaken = ($end - $start).TotalMilliseconds
        $result = [PSCustomObject]@{
            RequestNumber     = $requestNumber
            Url               = $url
            IpAddress         = $ip
            StatusCode        = $response.StatusCode
            ResponseTimeMs    = $timeTaken
            StatusDescription = $response.StatusDescription
            Timestamp         = $start
        }
        Log-Details "Request #$requestNumber to $url with IP $ip completed in $timeTaken ms with status code $($response.StatusCode) at $start"
    } catch {
        $result = [PSCustomObject]@{
            RequestNumber     = $requestNumber
            Url               = $url
            IpAddress         = $ip
            StatusCode        = "Failed"
            ResponseTimeMs    = "N/A"
            StatusDescription = $_.Exception.Message
            Timestamp         = (Get-Date)
        }
        Log-Details "Request #$requestNumber to $url with IP $ip failed: $($_.Exception.Message) at $(Get-Date)"
    }
    return $result
}

# Function to perform trace route for network diagnostics
function Trace-Route {
    param (
        [string]$url
    )
    $hostname = (New-Object System.Uri $url).Host
    $traceResult = tracert $hostname | Out-String
    Log-Details "Trace route for ${url}: $traceResult"
    return $traceResult
}

# Function to create a line chart
function Create-LineChart {
    param (
        [array]$data,
        [string]$title = "Response Times",
        [string]$xLabel = "Request Number",
        [string]$yLabel = "Response Time (ms)"
    )
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Windows.Forms.DataVisualization
    $chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
    $chart.Width = 800
    $chart.Height = 600

    $chartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
    $chartArea.AxisX.Title = $xLabel
    $chartArea.AxisY.Title = $yLabel
    $chart.ChartAreas.Add($chartArea)

    $series = New-Object System.Windows.Forms.DataVisualization.Charting.Series
    $series.Name = $title
    $series.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
    $chart.Series.Add($series)

    for ($i = 0; $i -lt $data.Length; $i++) {
        $chart.Series[$title].Points.AddXY($i + 1, $data[$i])
    }

    $chartForm = New-Object System.Windows.Forms.Form
    $chartForm.Text = $title
    $chartForm.Width = 820
    $chartForm.Height = 640
    $chart.Dock = [System.Windows.Forms.DockStyle]::Fill
    $chartForm.Controls.Add($chart)

    # Minimize the console window before showing the chart
    $sig = @"
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
"@
    Add-Type -MemberDefinition $sig -Name "Win32" -Namespace "Win32Functions"
    $consolePtr = [Win32Functions.Win32]::GetConsoleWindow()
    [Win32Functions.Win32]::ShowWindow($consolePtr, 6) # 6 = Minimize window

    $chartForm.ShowDialog()

    # Restore the console window after the chart is closed
    [Win32Functions.Win32]::ShowWindow($consolePtr, 9) # 9 = Restore window
}

# Main function to perform the test
function Test-UriPerformance {
    param (
        [string]$uri,
        [int]$totalRequests = 10,
        [int]$maxJobs = 3
    )

    # Resolve IP addresses for the URI
    $ipAddresses = Resolve-UriToIpAddress -uri $uri

    if ($ipAddresses.Count -eq 0) {
        Write-Output "Failed to resolve IP addresses. Exiting."
        return
    }

    # Store response times
    $responseTimes = [System.Collections.Generic.List[PSObject]]::new()

    # Function to start HTTP request jobs
    function Start-RequestJobs {
        param (
            [int]$totalRequests,
            [string]$uri,
            [array]$ipAddresses
        )
        
        $jobs = @()
        for ($i = 1; $i -le $totalRequests; $i++) {
            $ip = $ipAddresses[$i % $ipAddresses.Count]
            $jobs += Start-Job -ScriptBlock {
                param ($url, $ip, $requestNumber)

                function Get-HttpResponse {
                    param (
                        [string]$url,
                        [string]$ip,
                        [int]$requestNumber
                    )
                    try {
                        $start = Get-Date
                        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
                        $end = Get-Date
                        $timeTaken = ($end - $start).TotalMilliseconds
                        $result = [PSCustomObject]@{
                            RequestNumber     = $requestNumber
                            Url               = $url
                            IpAddress         = $ip
                            StatusCode        = $response.StatusCode
                            ResponseTimeMs    = $timeTaken
                            StatusDescription = $response.StatusDescription
                            Timestamp         = $start
                        }
                        Add-Content -Path "response_log.txt" -Value "Request #$requestNumber to $url with IP $ip completed in $timeTaken ms with status code $($response.StatusCode) at $start"
                    } catch {
                        $result = [PSCustomObject]@{
                            RequestNumber     = $requestNumber
                            Url               = $url
                            IpAddress         = $ip
                            StatusCode        = "Failed"
                            ResponseTimeMs    = "N/A"
                            StatusDescription = $_.Exception.Message
                            Timestamp         = (Get-Date)
                        }
                        Add-Content -Path "response_log.txt" -Value "Request #$requestNumber to $url with IP $ip failed: $($_.Exception.Message) at $(Get-Date)"
                    }
                    return $result
                }

                Get-HttpResponse -url $url -ip $ip -requestNumber $requestNumber
            } -ArgumentList $uri, $ip, $i
        }
        return $jobs
    }

    # Start jobs for HTTP requests
    $jobs = Start-RequestJobs -totalRequests $totalRequests -uri $uri -ipAddresses $ipAddresses

    # Monitor job progress
    $totalJobs = $jobs.Count
    $completedJobs = 0
    $failedCount = 0

    while ($completedJobs -lt $totalJobs) {
        $completedJobs = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
        $runningJobs = ($jobs | Where-Object { $_.State -eq 'Running' }).Count
        $remainingJobs = $totalJobs - $completedJobs - $runningJobs
        Write-Progress -Activity "Testing URI Performance" -Status "Running: $runningJobs, Completed: $completedJobs, Remaining: $remainingJobs" -PercentComplete (($completedJobs / $totalJobs) * 100)
        Start-Sleep -Seconds 1
    }

    # Wait for all jobs to complete
    $jobs | ForEach-Object { $_ | Wait-Job }

    # Collect results
    $responseTimes = $jobs | ForEach-Object { 
        $result = Receive-Job -Job $_
        if ($result.StatusCode -eq "Failed") {
            $failedCount++
        }
        Remove-Job -Job $_ -Force
        $result
    }

    # Run trace route if majority of the requests failed
    $traceRouteInfo = ""
    if ($failedCount -ge [math]::Ceiling($totalRequests / 2.0)) {
        Write-Output "Majority of requests failed. Running trace route..."
        $traceRouteInfo = Trace-Route -url $uri
    }

    # Create the table and prepare data for the chart
    $chartData = @()
    $responseTable = $responseTimes | ForEach-Object {
        if ($_.ResponseTimeMs -ne "N/A") {
            $chartData += [double]$_.ResponseTimeMs
        }
        [PSCustomObject]@{
            "Request Number"    = $_.RequestNumber
            "Timestamp"         = $_.Timestamp
            "IP Address"        = $_.IpAddress
            "Status Code"       = $_.StatusCode
            "Response Time (ms)"= $_.ResponseTimeMs
            "Status Description"= $_.StatusDescription
            "Trace Route"       = $traceRouteInfo
        }
    }

    # Display the trace route information in a readable format
    if ($traceRouteInfo -ne "") {
        Write-Output "Trace Route Information:"
        Write-Output $traceRouteInfo
    }

    # Display the results table
    $responseTable | Format-Table -AutoSize -Wrap
    Write-Output "URI: $uri"
    Write-Output "IP Addresses: $($ipAddresses -join ', ')"

    # Create and show the line chart
    Create-LineChart -data $chartData -title "Response Times for $uri"
}
