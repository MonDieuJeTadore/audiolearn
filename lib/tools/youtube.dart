import 'dart:io';
import 'package:audiolearn/constants.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path/path.dart' as path;
import 'package:logger/logger.dart';

void main() async {
  final yt = YoutubeExplode();
  final Logger logger = Logger();
  
  // Replace with your YouTube Playlist ID or URL
  // const playlistUrl = 'https://youtube.com/playlist?list=PLzwWSJNcZTMTFHT-VkbjScY0LKphiVN8D&si=Yd8btuQn_ZfEaLqa';
  const playlistUrl = 'https://youtube.com/playlist?list=PLCnrrahgI-og&si=e7hL1jHCr3ngJhPw';

  try {
    logger.i('Fetching playlist metadata...');
    final playlist = await yt.playlists.get(playlistUrl);
    logger.i('Downloading Playlist: ${playlist.title}');

    // Iterate through all videos in the playlist
    await for (final video in yt.playlists.getVideos(playlist.id)) {
      logger.i('\nProcessing video: ${video.title}');
      try {
        await downloadVideo(yt, video);
      } catch (e) {
        logger.i('Failed to download ${video.title}: $e');
      }
    }
  } catch (e) {
    logger.i('Error fetching playlist: $e');
  } finally {
    yt.close(); // Always close the client when done
  }
}

Future<void> downloadVideo(YoutubeExplode yt, Video video) async {
  final Logger logger = Logger();

  // Get the stream manifest (contains all available qualities/formats)
  final manifest = await yt.videos.streamsClient.getManifest(video.id);
  
  // Pick a muxed stream (video + audio combined, max 360p)
  // Note: For 1080p+, you would download video and audio-only streams separately
  // and mux them using an external tool like FFmpeg.
  final streamInfo = manifest.muxed.withHighestBitrate();

  // Create a safe file name by removing invalid characters
  final safeTitle = video.title.replaceAll(RegExp(r'[/\?<>\\:*|"]'), '');
  final file = File('$kApplicationPathWindowsTest${path.separator}$safeTitle.${streamInfo.container.name}');

  logger.i('Downloading to: ${file.path}');

  // Open the stream and write it to the file
  final stream = yt.videos.streamsClient.get(streamInfo);
  final fileStream = file.openWrite();

  await stream.pipe(fileStream);
  await fileStream.flush();
  await fileStream.close();

  logger.i('Download completed!');
}