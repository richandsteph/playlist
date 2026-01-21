```
Updates ID3 metadata with playlist XML input for song files (also uses command-line tools to populate remaining undefined tags from existing song metadata), then writes final version of metadata to playlist XML and updates song file metadata.
Includes scripts to create playlist XML from 'Music' folder (with artist & album sub-folders - must be run from 'Music' root folder), renumber playlist XML, & create playlist .m3u file from playlist XML.
  Usage:
    (for update_ID3_tags.pl) `perl update_ID3_tags.pl [PLAYLIST_XML_FILE]`
    (for remainder of scripts) `perl [SCRIPT_NAME]`
```
---
```

Playlist XML example:
<playlist name="rich-favorites" date="Tue Jan 20 21:09:59 2026">
  <song number="42">
    <track discnumber="1">04</track>
    <title>Hand in My Pocket</title>
    <artist>Alanis Morissette</artist>
    <albumartist>Alanis Morissette</albumartist>
    <album>Jagged Little Pill</album>
    <year>1995</year>
    <genre>Alternative Rock</genre>
    <bitrate unit="kbps">1616</bitrate>
    <length minutes="3:41">221</length>
    <comment></comment>
    <path>\DavisServer_1\Movies_Music_Pics\Music\Alanis Morissette\Jagged Little Pill [Explicit]\04 - Hand In My Pocket.flac</path>
  </song>
</playlist>
```
