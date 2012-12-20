param(
	[parameter(mandatory=$true)]
	[string]
	$bucketName,
	[parameter(mandatory=$true)]
	[string]
	$secretKeyID,
	[parameter(mandatory=$true)]
	[string]
	$secretAccessKeyID,
	[parameter(mandatory=$true)]
	[string]
	$databaseName,
	[parameter(mandatory=$true)]
	[string]
	$downloadDir,
	[parameter(mandatory=$false)]
	[string]
	$fromKeyNotInclusive,
	[parameter(mandatory=$false)]
	[string]
	$amazonSdkDllPath = "C:\Program Files (x86)\AWS SDK for .NET\bin\AWSSDK.dll")

if ([System.IO.Directory]::Exists($downloadDir) -eq $false){
	[System.IO.Directory]::CreateDirectory($downloadDir) | Out-Null
}
if (([System.IO.Directory]::GetFiles($downloadDir).Length -ne 0) -or 
	([System.IO.Directory]::GetDirectories($downloadDir).Length -ne 0)){
	"Output directory was not empty. Aborting export."
	exit -1
}

Add-Type -Path $amazonSdkDllPath

$config = New-Object -TypeName Amazon.S3.AmazonS3Config
$config.WithServiceUrl("s3-eu-west-1.amazonaws.com") | Out-Null
$config.WithCommunicationProtocol([Amazon.S3.Model.Protocol]::HTTPS) | Out-Null

$client=[Amazon.AWSClientFactory]::CreateAmazonS3Client($secretKeyID, $secretAccessKeyID, $config)

$listRequest = New-Object -TypeName Amazon.S3.Model.ListObjectsRequest
$listRequest.WithBucketName($bucketName).WithPrefix($databaseName) | Out-Null
if ($fromKeyNotInclusive -ne $null){
	$listRequest.WithMarker($fromKeyNotInclusive) | Out-Null
}

$listResponse = $client.ListObjects($listRequest)
$results = $listResponse.S3Objects

foreach($entry in $results){
	$getObjReq = New-Object -Type Amazon.S3.Model.GetObjectRequest
	$getObjReq.WithBucketName($bucketName).WithKey($entry.Key) | Out-Null
	$getObjResponse = $client.GetObject($getObjReq)
	$outputPath = $downloadDir + "\" + $entry.Key
	$getObjResponse.WriteResponseStreamToFile($outputPath)

	# Note: Smuggler imports by sorting on the GetLastWriteTime of each file. We can't rely on just saving the files
	# in the correct order here, because the MSDN docs say that GetLastWriteTime may return an inaccurate time. So
	# explicitly setting to original value
	$originalCreateTime = [System.DateTime]::Parse($entry.LastModified)
	[System.IO.File]::SetLastWriteTime($outputPath, $originalCreateTime.ToUniversalTime())

	"Wrote '$outputPath' with LastWriteTime of '$originalCreateTime'"

	$getObjResponse.Dispose()
}

# gci $dir | foreach-object { [System.IO.File]::GetLastWriteTime($_.FullName) }

$listResponse.Dispose()

$client.Dispose()
