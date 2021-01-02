""" Export all photos to specified directory using album names as folders
    If file has been edited, also export the edited version,
    otherwise, export the original version
    This will result in duplicate photos if photo is in more than album """

import os.path
import pathlib
import sys

from click import echo as print
import click
from osxphotos.photoinfo.photoinfo import PhotoInfo
from osxphotos.photoinfo import ExportResults
from osxphotos.albuminfo import AlbumInfo, FolderInfo
from pathvalidate import is_valid_filepath, sanitize_filepath
from osxphotos.export_db import ExportDB

import osxphotos


def is_jpeg(p: PhotoInfo):
    jpeg = [".jpg", ".jpeg", "jpg", "jpeg"]
    suffix = pathlib.Path(p.path).suffix.lower()
    return suffix in jpeg


def echo_export(exportResults: ExportResults):
    print()
    if exportResults.exported:
        print(f"Exported: {exportResults.exported}")
    if exportResults.new:
        print(f"New: {exportResults.new}")
    if exportResults.updated:
        print(f"Updated: {exportResults.updated}")
    if exportResults.skipped:
        print(f"Skipped: {exportResults.skipped}")
    if exportResults.exif_updated:
        print(f"Exif updated: {exportResults.exif_updated}")


def export_photo(p: PhotoInfo, destination: str, db: ExportDB):
    export_settings = {
        "use_persons_as_keywords": True,
        "exiftool": True,
        "update": True,
        "export_db": db,
        "convert_to_jpeg": True,
    }

    if not is_jpeg:
        export_settings["use_photos_export"] = True

    if p.isphoto and not p.hidden:
        if not p.ismissing:
            # export the photo
            if p.hasadjustments:
                if not p.path_edited:
                    export_settings["use_photos_export"] = True

                # export edited version
                exported = p.export2(destination, edited=True, **export_settings)
                # edited_name = pathlib.Path(p.path_edited).name
                echo_export(exported)
                # print(f"Exported {edited_name} to {exported}")
            else:
                try:
                    exported = p.export2(destination, **export_settings)
                    # print(f"Exported {p.filename} to {exported}")
                    echo_export(exported)
                except FileNotFoundError:
                    print(f"Path not found: {p.filename}, {p.album_info}")
        else:
            print(f"Skipping missing photo: {p.filename}")


def export_album(a: AlbumInfo, destination: str, db: ExportDB):
    name = sanitize_filepath(a.title, platform="auto")
    destination_path = os.path.join(destination, name)

    # verify path is a valid path
    if not is_valid_filepath(destination_path, platform="auto"):
        sys.exit(f"Invalid filepath {destination_path}")

    # create destination dir if needed
    if not os.path.isdir(destination_path):
        os.makedirs(destination_path)

    try:
        for p in a.photos:
            export_photo(p, destination_path, db)
    except IndexError as e:
        print(f"Album {a.title} has no photos, caused IndexError on .photos")
        print(e)
        # print(traceback.format_exc())
        print(a)
        print(len(a.photos))
        for p in a.photos:
            print(p.filename)
            export_photo(p, destination_path, db)


def export_folder(f: FolderInfo, destination: str, db: ExportDB):
    folder_name = sanitize_filepath(f.title, platform="auto")
    destination_path = os.path.join(destination, folder_name)

    # verify path is a valid path
    if not is_valid_filepath(destination_path, platform="auto"):
        sys.exit(f"Invalid filepath {destination_path}")

    # create destination dir if needed
    if not os.path.isdir(destination_path):
        os.makedirs(destination_path)

    for album in f.album_info:
        export_album(album, destination_path, db)

    for subfolder in f.subfolders:
        export_folder(subfolder, destination_path, db)


@click.command()
@click.argument("export_path", type=click.Path(exists=True))
@click.option(
    "--default-album",
    help="Default folder for photos with no album. Defaults to 'unfiled'",
    default="unfiled",
)
@click.option(
    "--library-path",
    help="Path to Photos library, default to last used library",
    default=None,
)
def export(export_path, default_album, library_path):
    export_path = os.path.expanduser(export_path)
    library_path = os.path.expanduser(library_path) if library_path else None

    dbname = os.path.join(export_path, ".osxphotos_export.db")
    db = ExportDB(dbname)

    if library_path is not None:
        photosdb = osxphotos.PhotosDB(library_path)
    else:
        photosdb = osxphotos.PhotosDB()

    for folder in photosdb.folder_info:
        export_folder(folder, export_path, db)


if __name__ == "__main__":
    export()  # pylint: disable=no-value-for-parameter
