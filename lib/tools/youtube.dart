import 'dart:io';
import 'package:audiolearn/constants.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path/path.dart' as path;

void main() async {
  final yt = YoutubeExplode();
  
  // Replace with your YouTube Playlist ID or URL
  // const playlistUrl = 'https://youtube.com/playlist?list=PLzwWSJNcZTMTFHT-VkbjScY0LKphiVN8D&si=Yd8btuQn_ZfEaLqa';
  const playlistUrl = 'https://youtube.com/playlist?list=PLCnrrahgI-og&si=e7hL1jHCr3ngJhPw';

  try {
    print('Fetching playlist metadata...');
    final playlist = await yt.playlists.get(playlistUrl);
    print('Downloading Playlist: ${playlist.title}');

    // Iterate through all videos in the playlist
    await for (final video in yt.playlists.getVideos(playlist.id)) {
      print('\nProcessing video: ${video.title}');
      try {
        await downloadVideo(yt, video);
      } catch (e) {
        print('Failed to download ${video.title}: $e');
      }
    }
  } catch (e) {
    print('Error fetching playlist: $e');
  } finally {
    yt.close(); // Always close the client when done
  }
}

Future<void> downloadVideo(YoutubeExplode yt, Video video) async {
  // Get the stream manifest (contains all available qualities/formats)
  final manifest = await yt.videos.streamsClient.getManifest(video.id);
  
  // Pick a muxed stream (video + audio combined, max 360p)
  // Note: For 1080p+, you would download video and audio-only streams separately
  // and mux them using an external tool like FFmpeg.
  final streamInfo = manifest.muxed.withHighestBitrate();

  // Create a safe file name by removing invalid characters
  final safeTitle = video.title.replaceAll(RegExp(r'[/\?<>\\:*|"]'), '');
  final file = File('$kApplicationPathWindowsTest${path.separator}$safeTitle.${streamInfo.container.name}');

  print('Downloading to: ${file.path}');

  // Open the stream and write it to the file
  final stream = yt.videos.streamsClient.get(streamInfo);
  final fileStream = file.openWrite();

  await stream.pipe(fileStream);
  await fileStream.flush();
  await fileStream.close();

  print('Download completed!');
}