
# This is a python script that will synchronize all the important files/folders with the computer.
# This project with the .git exceeds Computercraft's computer memory limits.
# Changing the destination, then running this with python will solve this issue by
#  Only putting in the important files into the computer save folder.

import os
import fnmatch
import time
import shutil
import datetime

cwd = os.getcwd()  # Source directory

########
##! Change the following to your destination folder, aka your computer's folder
########
# example "[Previous path] .. \minecraft\saves\worldname\computercraft\computer\0"
destination = r""

if destination == "":
	raise Exception("Please provide your computercraft computer's location.")


# Wildcard blacklist (can add '*.git*', '*.tmp', etc.)
blacklist = [
	".git",        # ignores .git folder and its contents
	"*.tmp",       # ignores tmp files
	"*.log",        # ignores logs
	".vscode",
	".gitignore",
	"ReadMe.md",
	"LICENSE",
	"sync.py"
]

# Dictionary to store last modified times
last_mtimes = {}

def is_blacklisted(path: str) -> bool:
	"""Check if a file or folder matches the blacklist patterns."""
	for pattern in blacklist:
		if fnmatch.fnmatch(path, pattern) or pattern in path:
			return True
	return False

def check_and_copy():
	global last_mtimes

	for root, dirs, files in os.walk(cwd):
		# Skip blacklisted directories
		dirs[:] = [d for d in dirs if not is_blacklisted(d)]

		for file in files:
			src_path = os.path.join(root, file)

			# Skip blacklisted files
			rel_path = os.path.relpath(src_path, cwd)
			if is_blacklisted(rel_path):
				continue

			# Check if modified
			mtime = os.path.getmtime(src_path)
			if rel_path not in last_mtimes or mtime > last_mtimes[rel_path]:
				last_mtimes[rel_path] = mtime

				# Copy to destination (preserve directory structure)
				dest_path = os.path.join(destination, rel_path)
				os.makedirs(os.path.dirname(dest_path), exist_ok=True)
				shutil.copy2(src_path, dest_path)
				print(f"{datetime.datetime.now().time()} Copied: {rel_path}")

if __name__ == "__main__":
	print("Watching for changes... (Press Ctrl+C to stop)")
	try:
		while True:
			check_and_copy()
			time.sleep(5)
	except KeyboardInterrupt:
		print("Stopped.")