# Step 1: unlock files first (may be read-only from previous run)
$pluginsCmake = "windows\flutter\generated_plugins.cmake"
$pluginRegistrant = "windows\flutter\generated_plugin_registrant.cc"
if (Test-Path $pluginsCmake) {
    Set-ItemProperty $pluginsCmake -Name IsReadOnly -Value $false
}
if (Test-Path $pluginRegistrant) {
    Set-ItemProperty $pluginRegistrant -Name IsReadOnly -Value $false
}

# Step 2: pub get regenerates both files
flutter pub get

# Step 3: patch generated_plugins.cmake
$content = Get-Content $pluginsCmake -Raw
$fixed = $content -replace "  ffmpeg_kit_flutter_new`r`n", ""
$fixed = $fixed -replace "  ffmpeg_kit_flutter_new`n", ""
Set-Content $pluginsCmake $fixed -NoNewline
Write-Host "Done: generated_plugins.cmake patched"

# Step 4: patch generated_plugin_registrant.cc
$content = Get-Content $pluginRegistrant -Raw
$fixed = $content -replace "#include <ffmpeg_kit_flutter_new/f_fmpeg_kit_flutter_plugin.h>`r`n", ""
$fixed = $fixed -replace "#include <ffmpeg_kit_flutter_new/f_fmpeg_kit_flutter_plugin.h>`n", ""
$fixed = $fixed -replace "  FFmpegKitFlutterPluginRegisterWithRegistrar\(`r`n      registry->GetRegistrarForPlugin\(""FFmpegKitFlutterPlugin""\)\);`r`n", ""
$fixed = $fixed -replace "  FFmpegKitFlutterPluginRegisterWithRegistrar\(`n      registry->GetRegistrarForPlugin\(""FFmpegKitFlutterPlugin""\)\);`n", ""
Set-Content $pluginRegistrant $fixed -NoNewline
Write-Host "Done: generated_plugin_registrant.cc patched"

# Step 5: build without re-running pub get
flutter build windows --release --no-pub
