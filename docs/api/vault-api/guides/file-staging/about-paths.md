<!-- source: https://general.veevavault.dev/vault-api/guides/file-staging/about-paths/ -->
<!-- title: About File Staging Paths -->

# About File Staging Paths

User directories are always in the format `u{user_id}`.

Paths to files and folders are different for Admin and non-Admin users:

* **Non-Admin** users can only see their own files and folders. Non-Admin users must include the full path from their user directory’s root. For example, `/Folder/File.txt`.
* **Admin** users can see all files and folders on their Vault's file staging, including the root directory and individual user directories. Admin users must include the full path from file staging's root directory, even for files and folders in their own user directory. For example, `/u1234/Folder/File.txt`.

For example:

* Olivia is not a Vault Owner or System Admin, and her user ID is `1234`. Her path to a file in a folder on her user directory is `/Folder/File.txt`.
* Allison is a System Admin. Her path to the same file would be `/u1234/Folder/File.txt`.
* For Allison, a file at `/Folder/File.txt` is in a folder on her file staging’s root directory and not in any individual user directory.
* If Allison’s the System Admin's user ID is `5678`, her path to a file in a folder on her own user directory is `/u5678/Folder/File.txt`.
