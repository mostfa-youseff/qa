# qa_module

## Overview
A quality assurance tool for generating documentation (README, Wiki) and tests (unit, integration, widget) for Dart projects using CodeLLaMA-7B with a test-specific adapter checkpoint via FFI. Supports Markdown, RST, and AsciiDoc formats, with export to MkDocs, Hugo, and AsciiDoctor. Provides CLI and REST API interfaces.

## Installation
1. Install Dart SDK: `>=3.0.0 <4.0.0`
2. Install Python 3.10 and required libraries: `pip install transformers peft cffi torch`
3. Install Redis: `localhost:6379`
4. Install Qdrant: `localhost:6333`
5. Clone the repository: `git clone <repo-url>`
6. Run `dart pub get` to install Dart dependencies.
7. Build the Python shared library:
   ```bash
   cd python
   python build_ffi.py
