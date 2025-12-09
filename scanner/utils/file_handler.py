"""File handling utilities"""

import os
from typing import List


class FileHandler:
    """Handle file and directory operations for scanning"""

    def __init__(self, exclude_dirs: List[str] = None, exclude_extensions: List[str] = None):
        self.exclude_dirs = exclude_dirs or [
            '.git', 'node_modules', '__pycache__', 'venv', '.venv',
            'dist', 'build', '.pytest_cache', '.mypy_cache'
        ]
        self.exclude_extensions = exclude_extensions or [
            '.jpg', '.jpeg', '.png', '.gif', '.pdf', '.zip',
            '.tar', '.gz', '.bz2', '.mp4', '.mp3', '.avi',
            '.test.js'  # Exclude test files (may contain dummy secrets)
        ]

    def should_scan_file(self, filepath: str) -> bool:
        """Check if file should be scanned"""
        # Check excluded extensions
        if any(filepath.lower().endswith(ext) for ext in self.exclude_extensions):
            return False

        # Check if file is readable
        if not os.path.isfile(filepath):
            return False

        # Check file size (skip files > 10MB)
        try:
            if os.path.getsize(filepath) > 10 * 1024 * 1024:
                return False
        except OSError:
            return False

        return True

    def should_scan_directory(self, dirname: str) -> bool:
        """Check if directory should be scanned"""
        return dirname not in self.exclude_dirs

    def walk_directory(self, path: str):
        """Generator for walking directory tree"""
        for root, dirs, files in os.walk(path):
            # Filter directories in place
            dirs[:] = [d for d in dirs if self.should_scan_directory(d)]

            for filename in files:
                filepath = os.path.join(root, filename)
                if self.should_scan_file(filepath):
                    yield filepath
