$pluginsCmake = "windows\flutter\generated_plugins.cmake"
$pluginRegistrant = "windows\flutter\generated_plugin_registrant.cc"
if (Test-Path $pluginsCmake) {
    Set-ItemProperty $pluginsCmake -Name IsReadOnly -Value $false
}
if (Test-Path $pluginRegistrant) {
    Set-ItemProperty $pluginRegistrant -Name IsReadOnly -Value $false
}

flutter pub get

$content = Get-Content $pluginsCmake -Raw
$fixed = $content -replace "  ffmpeg_kit_flutter_new`r`n", ""
$fixed = $fixed -replace "  ffmpeg_kit_flutter_new`n", ""
Set-Content $pluginsCmake $fixed -NoNewline

$content = Get-Content $pluginRegistrant -Raw
$fixed = $content -replace "#include <ffmpeg_kit_flutter_new/f_fmpeg_kit_flutter_plugin.h>`r`n", ""
$fixed = $fixed -replace "#include <ffmpeg_kit_flutter_new/f_fmpeg_kit_flutter_plugin.h>`n", ""
$fixed = $fixed -replace "  FFmpegKitFlutterPluginRegisterWithRegistrar\(`r`n      registry->GetRegistrarForPlugin\(""FFmpegKitFlutterPlugin""\)\);`r`n", ""
$fixed = $fixed -replace "  FFmpegKitFlutterPluginRegisterWithRegistrar\(`n      registry->GetRegistrarForPlugin\(""FFmpegKitFlutterPlugin""\)\);`n", ""
Set-Content $pluginRegistrant $fixed -NoNewline

Write-Host "Done: files patched, ready to debug"
