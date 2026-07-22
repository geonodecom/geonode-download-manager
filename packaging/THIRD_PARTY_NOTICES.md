# Third-Party Notices

Geonode Download Manager release builds may bundle the following third-party
tools in the `bin/` directory (desktop) or app assets (Android):

## aria2

- Project: https://github.com/aria2/aria2
- License: GPL-2.0-or-later
- Used for direct HTTP/HTTPS segmented downloads on desktop.

## yt-dlp

- Project: https://github.com/yt-dlp/yt-dlp
- License: Unlicense
- Used for YouTube metadata extraction and downloads.

## ffmpeg

- Project: https://ffmpeg.org/
- License: GPL-2.0-or-later / LGPL-2.1-or-later (depending on build)
- Used to mux combined YouTube video and audio streams.
- Desktop builds typically use [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds).
- Android builds use static binaries from [Tyrrrz/FFmpegBin](https://github.com/Tyrrrz/FFmpegBin).

## Source code

Corresponding source code for GPL-licensed components is available from the
project URLs above. If you received a binary release and need matching source
for ffmpeg or aria2, contact the project maintainer or obtain source from the
official project sites listed above.
