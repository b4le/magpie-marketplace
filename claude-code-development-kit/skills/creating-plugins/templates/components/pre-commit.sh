#!/bin/bash
# Pre-commit hook - runs before commits

echo "Running linter..."
npm run lint

if [ $? -ne 0 ]; then
  echo "Linting failed. Fix errors before committing."
  exit 1
fi

echo "Running tests..."
npm test

exit $?