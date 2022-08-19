#!/usr/bin/env powershell
param([switch]$commit=$false,[switch]$useLocal=$false)

# Use newer TLS versions
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

$clientsDir = Resolve-Path -Path "./clients/"
$templatesDir = Resolve-Path -Path "./templates/"

$languages = "csharp-netcore", "java", "php", "python", "ruby", "swift5"
$apis = "merchant", "channel"
$hostName = "https://demo.channelengine.net"

If($useLocal) {
    $hostName = "http://dev.channelengine.local"
}

ForEach($api in $apis)
{
    $specUrl = "$hostName/api/swagger/$api/swagger.json"
    $spec = Invoke-RestMethod -Uri $specUrl
    #$version = $spec."info"."version"
	$version = "2.12.0"
    Write-Host $version

    $pathHelper = $ExecutionContext.SessionState.Path
    $workingDir = Get-Location

    # Fetch the clients from swagger api
    ForEach($language in $languages)
    {
        $clientLanguage = $language;
        if($language -eq "swift5") {
            $clientLanguage = "swift";
        }
        if($language -eq "csharp-netcore") {
            $clientLanguage = "csharp";
        }

        $targetPath = $pathHelper.GetUnresolvedProviderPathFromPSPath("$clientsDir/$api-api-client-$clientLanguage")
        $configPath = "$targetPath\swagger-config.json"

        Write-Host $targetPath
        Write-Host $specUrl

        # Swagger codegen won't regenerate files like pom.xml and build.gradle, but they contain the package version.
        # Delete them to force regeneration.
        if($language -eq "java") {
            Remove-Item "$targetPath/pom.xml", "$targetPath/build.gradle", "$targetPath/build.sbt" -ErrorAction Ignore
        }
        
        $gitPath = $targetPath
        $templatePath = $pathHelper.GetUnresolvedProviderPathFromPSPath("$templatesDir/$clientLanguage")

        $templateDirParameter = "";
        $versionProps = @{
            artifactVersion = $version;
            packageVersion = $version;
            gemVersion = $version;
            podVersion = $version;
        }

        $versionPropsString = ($versionProps.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ','

        # Generate everything (models, api, supporting files) without docs and tests
        $systemParams = "-Dmodels -DmodelDocs=false -DmodelTests=false -Dapis -DapiDocs=false -DapiTests=false -DsupportingFiles"
        $javaCommand = "java $systemParams -jar "
        $swaggerCommand = """$workingDir\openapi-generator-cli-6.0.0.jar"" generate "
        $swaggerCommand += "-i $specUrl "
        $swaggerCommand += "-g $language "
        $swaggerCommand += "-o ""$targetPath"""
        $swaggerCommand += "--config ""$configPath"""
        $swaggerCommand += "--additional-properties ""$versionPropsString"""
        if(Test-Path($templatePath)) {
            $swaggerCommand += "-t ""$templatePath"""
        }

        $command = $javaCommand + $swaggerCommand
        
        Write-Host $command
        Write-Host "------------"
        Invoke-Expression $command
        Write-Host "------------"
        
        Set-Location $targetPath

        git checkout master
		git pull
        # Always run git add to fix newline issues on windows
		git add .

        if($commit) {
            git commit -m "Generate version $version"
            git tag -a "v$version" -m "Version $version"
            git push origin master --tags
        }
        
        Set-Location $workingDir

        Write-Host "------------"
    }
}