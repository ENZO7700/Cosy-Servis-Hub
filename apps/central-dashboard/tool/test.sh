#!/bin/bash
set -e

echo "=== Running Unit Tests ==="
flutter test test/unit

echo ""
echo "=== Running Repository Tests ==="
flutter test test/repository

echo ""
echo "=== Running Widget Tests ==="
flutter test test/widget

echo ""
echo "=== All Tests Passed! ==="
