# qa_module

## Overview
A quality assurance tool for generating documentation (README, Wiki) and tests (unit, integration, widget) for Dart projects using a fine-tuned CodeLLaMA-7B model. Supports Markdown, RST, and AsciiDoc formats, with export to MkDocs, Hugo, and AsciiDoctor. Provides CLI and REST API interfaces.

## Installation
1. Install Dart SDK: `>=3.0.0 <4.0.0`
2. Install Redis: `localhost:6379`
3. Install Qdrant: `localhost:6333`
4. Clone the repository: `git clone <repo-url>`
5. Run `dart pub get` to install dependencies.
6. Ensure model path `/mnt/data/codellama_7b_finetuned/checkpoint-700` is accessible.
7. Start the mock API server for CodeLLaMA at `http://localhost:8000/inference`.

## Usage
### CLI
```bash
# Generate documentation (Markdown, README only)
dart run bin/qa_module.dart --module documentation --repo-url https://github.com/user/repo --doc-format markdown --doc-output-type readme

# Generate documentation (RST, Wiki only)
dart run bin/qa_module.dart --module documentation --repo-url https://github.com/user/repo --doc-format rst --doc-output-type wiki

# Generate unit tests for a file
dart run bin/qa_module.dart --module test-generation --file lib/main.dart --test-type unit

# Generate integration tests for a private repository
dart run bin/qa_module.dart --module test-generation --repo-url https://github.com/user/private-repo --token <your-token> --test-type integration

# Run in interactive mode
dart run bin/qa_module.dart --interactive

# Start API server
dart run bin/qa_module.dart --api
```

### API
Start the API server:
```bash
dart run bin/qa_module.dart --api
```

Endpoints:
- `POST /api/documentation`
  - Body: `{"repoUrl": "https://github.com/user/repo", "format": "markdown", "outputType": "both"}`
  - Response: `{"documentation": {"readme": "<content>", "wiki": "<content>"}}`
- `POST /api/test-generation`
  - Body: `{"filePath": "lib/main.dart", "testType": "unit"}` or `{"repoUrl": "https://github.com/user/repo", "token": "<your-token>", "testType": "integration"}`
  - Response: `{"tests": {"file1.dart": "<content>", "file2.dart": "<content>"}}`

## Structure
- `bin/`: CLI entry point.
- `lib/core/`: Shared services (`model_service`, `cli_manager`, `api_server`).
- `lib/modules/documentation/`: Documentation generation module (Markdown, RST, AsciiDoc, MkDocs, Hugo, AsciiDoctor).
- `lib/modules/test_generation/`: Test generation module (unit, integration, widget).
- `lib/shared/`: Shared utilities (`git_service`, `cache_service`).
- `config/`: Configuration files.
- `example/`: Sample repository and outputs.
- `tests/`: Unit and integration tests.

## Requirements
- Dart SDK
- Redis
- Qdrant
- Git
- CodeLLaMA-7B model at `/mnt/data/codellama_7b_finetuned/checkpoint-700`
