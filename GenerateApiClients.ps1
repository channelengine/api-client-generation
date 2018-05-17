param([bool]$commit=$false)

$clientsDir = Resolve-Path -Path "./clients/"
$templatesDir = Resolve-Path -Path "./templates/"

$languages = "php", "swift4", "ruby", "csharp", "java", "python"
$apis = "channel", "merchant"

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
        $targetPath = $pathHelper.GetUnresolvedProviderPathFromPSPath("$clientsDir/$language-$api")
        if(-Not(Test-Path $targetPath)) { New-Item -ItemType directory -Path $targetPath | Out-Null }

        Write-Host $targetPath
        Write-Host $specUrl

        $gitPath = $targetPath
        $templatePath = $pathHelper.GetUnresolvedProviderPathFromPSPath("$templatesDir/$language")
        $repoUrl = "git@github.com:channelengine/$api-api-client-$language.git"
        $mavenRepoUrl = "scm:git:git://github.com:channelengine/$api-api-client-$language.git"
        $githubUrl = "https://github.com/channelengine/$api-api-client-$language"
        $description = "ChannelEngine $api API Client for $language"

        $author = "Christiaan de Ridder";
        $authorEmail = "support@channelengine.com";
        $website = "https://www.channelengine.com";

        $templateDirParameter = "";
        $additionalProps = @{
            variableNamingConvention = "camelCase";
            packagePath = "ChannelEngine";

            composerVendorName = "channelengine";
            composerProjectName = "$api-api-client-$language";

            gitUserId = "channelengine";
            gitRepoId = "$api-api-client-$language";

            artifactId = "$api-api-client-$language";
            artifactVersion = $version;
            artifactUrl = $githubUrl;
            artifactDescription = $description;

            scmConnection = $mavenRepoUrl;
            scmDeveloperConnection = $mavenRepoUrl
            scmUrl = $githubUrl;

            developerName = $author;
            developerEmail = $authorEmail;
            developerOrganization = "ChannelEngine";
            developerOrganizationUrl = $website;

            licenseName = "MIT";
            licenseUrl = "https://opensource.org/licenses/mit-license.php"

        }

        if($language -eq "swift4") {
            $additionalProps.projectName = "ChannelEngine$($apiLabel)ApiClient"
            #$additionalProps.podSource = ""
            $additionalProps.podVersion = $version
            $additionalProps.podAuthors = $author
            $additionalProps.podHomepage = $website
            $additionalProps.podDescription = $description
        }

        if($language -eq "php") {
            #$gitPath = $pathHelper.GetUnresolvedProviderPathFromPSPath($targetPath + "\ChannelEngine")
            $additionalProps.invokerPackage = "ChannelEngine\$($apiLabel)\ApiClient"
            $additionalProps.modelPackage = "Model"
            $additionalProps.apiPackage = "Api"
            $additionalProps.packagePath = ""
        }

        if($language -eq "csharp") {

            $additionalProps.packageName = "ChannelEngine.$apiLabel.ApiClient"
            $additionalProps.packageVersion = $version
            $additionalProps.modelPackage = "Model"
            $additionalProps.apiPackage = "Api"
        }

        if($language -eq "java") {
            $additionalProps.groupId = "com.channelengine.$api.apiclient";
            $additionalProps.invokerPackage = "com.channelengine.$api.apiclient";
            $additionalProps.modelPackage = "com.channelengine.$api.apiclient.model";
            $additionalProps.apiPackage = "com.channelengine.$api.apiclient.api";
        }

        if($language -eq "python") {
            $additionalProps.packageName = "channelengine_$($api)_api_client"
            $additionalProps.packageVersion = $version
        }

        if($language -eq "ruby") {
            $additionalProps.gemName = "channelengine_$($api)_api_client_$language"
            $additionalProps.gemSummary = $description
            $additionalProps.gemAuthor = $author
            $additionalProps.gemAuthorEmail = $authorEmail
            $additionalProps.gemHomepage = $website
            $additionalProps.gemVersion = $version
            $additionalProps.moduleName = "ChannelEngine$($apiLabel)ApiClient"
        }

        $additionalPropsString = ($additionalProps.GetEnumerator() | % { "$($_.Key)=$($_.Value)" }) -join ','
        
        Write-Host $gitPath

        if(-Not(Test-Path $pathHelper.GetUnresolvedProviderPathFromPSPath($gitPath + "\.git"))) { 
            git clone "$repoUrl" $gitPath
        }

        Set-Location $gitPath
        git pull origin master

        # Generate everything (models, api, supporting files) without docs and tests
        $systemParams = "-Dmodels -DmodelDocs=false -DmodelTests=false -Dapis -DapiDocs=false -DapiTests=false -DsupportingFiles"
        $javaCommand = "java $systemParams -jar "
        $swaggerCommand = """$workingDir\swagger-codegen-cli-2.4.0.jar"" generate "
        $swaggerCommand += "-i $specUrl "
        $swaggerCommand += "-l $language "
        $swaggerCommand += "-o ""$targetPath"""
        if(Test-Path($templatePath)) {
            $swaggerCommand += "-t ""$templatePath"""
        }
        $swaggerCommand += "--additional-properties ""$additionalPropsString"""

        $command = $javaCommand + $swaggerCommand
        Write-Host $command
        Invoke-Expression $command

        if($commit) {
            git add .
            git commit -m "Generate version $version"
            git tag -a "v$version" -m "Version $version"
            git push origin master --tags
        }
        
        Set-Location $workingDir
    }
}