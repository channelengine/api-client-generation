param([switch]$commit=$false)

$clientsDir = Resolve-Path -Path "./clients/"
$templatesDir = Resolve-Path -Path "./templates/"

$languages = "csharp", "java", "php", "python", "ruby", "swift4"
$apis = "merchant", "channel"

ForEach($api in $apis)
{
    $specUrl = "https://demo.channelengine.net/api/swagger/docs/$api"
    $spec = Invoke-RestMethod -Uri $specUrl
    $version = $spec.info.version
    Write-Host $version

    $apiLabel =  (Get-Culture).TextInfo.ToTitleCase($api)
    $pathHelper = $ExecutionContext.SessionState.Path
    $workingDir = Get-Location

    # Fetch the clients from swagger api
    ForEach($language in $languages)
    {
        $targetPath = $pathHelper.GetUnresolvedProviderPathFromPSPath("$clientsDir/$api-api-client-$language")
        $configPath = "$targetPath\swagger-config.json"

        Write-Host $targetPath
        Write-Host $specUrl

        $gitPath = $targetPath
        $templatePath = $pathHelper.GetUnresolvedProviderPathFromPSPath("$templatesDir/$language")

        $templateDirParameter = "";
        $versionProps = @{
            artifactVersion = $version;
            packageVersion = $version;
            gemVersion = $version;
            podVersion = $version;
        }

        $versionPropsString = ($versionProps.GetEnumerator() | % { "$($_.Key)=$($_.Value)" }) -join ','

        # Generate everything (models, api, supporting files) without docs and tests
        $systemParams = "-Dmodels -DmodelDocs=false -DmodelTests=false -Dapis -DapiDocs=false -DapiTests=false -DsupportingFiles"
        $javaCommand = "java $systemParams -jar "
        $swaggerCommand = """$workingDir\swagger-codegen-cli-2.4.0.jar"" generate "
        $swaggerCommand += "-i $specUrl "
        $swaggerCommand += "-l $language "
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