# GitHub Actions Workflows

Since the GitHub App doesn't have workflows permission, these workflow files need to be added manually. Create the following directory structure and files:

## Directory Structure

```
.github/
└── workflows/
    ├── ci.yml
    ├── release.yml
    └── multiplatform.yml
```

## 1. CI Workflow (`.github/workflows/ci.yml`)

```yaml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0  # Fetch all history for git describe
    
    - name: Setup Swift
      uses: swift-actions/setup-swift@v1
      with:
        swift-version: '5.9'
    
    - name: Cache Swift packages
      uses: actions/cache@v3
      with:
        path: .build
        key: ${{ runner.os }}-swift-${{ hashFiles('**/Package.resolved') }}
        restore-keys: |
          ${{ runner.os }}-swift-
    
    - name: Build and test
      run: |
        chmod +x build.sh
        ./build.sh debug --test --clean
    
    - name: Upload test results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: test-results
        path: .build/debug/
        retention-days: 7

  lint:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Swift
      uses: swift-actions/setup-swift@v1
      with:
        swift-version: '5.9'
    
    - name: Install SwiftLint
      run: brew install swiftlint
    
    - name: Run SwiftLint
      run: swiftlint --strict
      continue-on-error: true  # Don't fail the build on lint warnings initially
    
    - name: Install swift-format
      run: brew install swift-format
    
    - name: Check formatting
      run: swift-format lint --recursive DidYouGet/
      continue-on-error: true  # Don't fail the build on format issues initially
```

## 2. Release Workflow (`.github/workflows/release.yml`)

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  create-release:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0  # Fetch all history for git describe
    
    - name: Setup Swift
      uses: swift-actions/setup-swift@v1
      with:
        swift-version: '5.9'
    
    - name: Cache Swift packages
      uses: actions/cache@v3
      with:
        path: .build
        key: ${{ runner.os }}-swift-${{ hashFiles('**/Package.resolved') }}
        restore-keys: |
          ${{ runner.os }}-swift-
    
    - name: Get version from tag
      id: get_version
      run: |
        VERSION=${GITHUB_REF#refs/tags/v}
        echo "version=$VERSION" >> $GITHUB_OUTPUT
        echo "tag=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT
    
    - name: Run tests
      run: |
        chmod +x build.sh
        ./build.sh debug --test --clean
    
    - name: Build release
      run: |
        ./build.sh release
    
    - name: Create release archive
      run: |
        cd release
        tar -czf DidYouGet-${{ steps.get_version.outputs.version }}-macos.tar.gz DidYouGet version.txt
    
    - name: Generate release notes
      id: release_notes
      run: |
        # Get the previous tag
        PREVIOUS_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
        
        # Generate changelog
        if [ -n "$PREVIOUS_TAG" ]; then
          CHANGELOG=$(git log --pretty=format:"- %s" $PREVIOUS_TAG..HEAD)
        else
          CHANGELOG=$(git log --pretty=format:"- %s" HEAD)
        fi
        
        # Create release notes
        cat > release_notes.md << EOF
        # Release ${{ steps.get_version.outputs.version }}
        
        ## Changes
        $CHANGELOG
        
        ## Installation
        1. Download the \`DidYouGet-${{ steps.get_version.outputs.version }}-macos.tar.gz\` file
        2. Extract it: \`tar -xzf DidYouGet-${{ steps.get_version.outputs.version }}-macos.tar.gz\`
        3. Run the executable: \`./DidYouGet\`
        
        ## Requirements
        - macOS 13.0 or later
        - Screen recording permissions may be required
        
        ## Full Changelog
        **Full Changelog**: https://github.com/${{ github.repository }}/compare/$PREVIOUS_TAG...${{ steps.get_version.outputs.tag }}
        EOF
    
    - name: Create GitHub Release
      uses: softprops/action-gh-release@v1
      with:
        tag_name: ${{ steps.get_version.outputs.tag }}
        name: Release ${{ steps.get_version.outputs.version }}
        body_path: release_notes.md
        files: |
          release/DidYouGet-${{ steps.get_version.outputs.version }}-macos.tar.gz
          release/version.txt
        draft: false
        prerelease: false
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Upload build artifacts
      uses: actions/upload-artifact@v3
      with:
        name: release-artifacts
        path: |
          release/DidYouGet-${{ steps.get_version.outputs.version }}-macos.tar.gz
          release/version.txt
        retention-days: 90
```

## 3. Multiplatform Workflow (`.github/workflows/multiplatform.yml`)

```yaml
name: Multiplatform Build

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to build'
        required: true
        default: '1.0.0'

jobs:
  build-universal:
    runs-on: macos-latest
    
    strategy:
      matrix:
        arch: [x86_64, arm64]
    
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0
    
    - name: Setup Swift
      uses: swift-actions/setup-swift@v1
      with:
        swift-version: '5.9'
    
    - name: Get version
      id: get_version
      run: |
        if [ "${{ github.event_name }}" = "push" ]; then
          VERSION=${GITHUB_REF#refs/tags/v}
        else
          VERSION=${{ github.event.inputs.version }}
        fi
        echo "version=$VERSION" >> $GITHUB_OUTPUT
    
    - name: Cache Swift packages
      uses: actions/cache@v3
      with:
        path: .build
        key: ${{ runner.os }}-${{ matrix.arch }}-swift-${{ hashFiles('**/Package.resolved') }}
        restore-keys: |
          ${{ runner.os }}-${{ matrix.arch }}-swift-
    
    - name: Build for ${{ matrix.arch }}
      run: |
        chmod +x build.sh
        if [ "${{ matrix.arch }}" = "arm64" ]; then
          swift build -c release --arch arm64
        else
          swift build -c release --arch x86_64
        fi
    
    - name: Create architecture-specific release
      run: |
        mkdir -p release/${{ matrix.arch }}
        if [ "${{ matrix.arch }}" = "arm64" ]; then
          cp .build/arm64-apple-macosx/release/DidYouGet release/${{ matrix.arch }}/
        else
          cp .build/x86_64-apple-macosx/release/DidYouGet release/${{ matrix.arch }}/
        fi
        
        # Create version info
        cat > release/${{ matrix.arch }}/version.txt << EOF
        DidYouGet ${{ steps.get_version.outputs.version }}
        Architecture: ${{ matrix.arch }}
        Built: $(date)
        Platform: macOS
        EOF
    
    - name: Upload architecture artifact
      uses: actions/upload-artifact@v3
      with:
        name: didyouget-${{ matrix.arch }}
        path: release/${{ matrix.arch }}/
        retention-days: 7

  create-universal-binary:
    needs: build-universal
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0
    
    - name: Get version
      id: get_version
      run: |
        if [ "${{ github.event_name }}" = "push" ]; then
          VERSION=${GITHUB_REF#refs/tags/v}
          TAG=${GITHUB_REF#refs/tags/}
        else
          VERSION=${{ github.event.inputs.version }}
          TAG=v$VERSION
        fi
        echo "version=$VERSION" >> $GITHUB_OUTPUT
        echo "tag=$TAG" >> $GITHUB_OUTPUT
    
    - name: Download x86_64 artifact
      uses: actions/download-artifact@v3
      with:
        name: didyouget-x86_64
        path: release/x86_64/
    
    - name: Download arm64 artifact
      uses: actions/download-artifact@v3
      with:
        name: didyouget-arm64
        path: release/arm64/
    
    - name: Create universal binary
      run: |
        mkdir -p release/universal
        
        # Create universal binary using lipo
        lipo -create \
          release/x86_64/DidYouGet \
          release/arm64/DidYouGet \
          -output release/universal/DidYouGet
        
        # Make it executable
        chmod +x release/universal/DidYouGet
        
        # Create version info
        cat > release/universal/version.txt << EOF
        DidYouGet ${{ steps.get_version.outputs.version }}
        Architecture: Universal (x86_64 + arm64)
        Built: $(date)
        Platform: macOS
        EOF
        
        # Verify the universal binary
        file release/universal/DidYouGet
        lipo -info release/universal/DidYouGet
    
    - name: Create release packages
      run: |
        cd release
        
        # Create individual architecture packages
        tar -czf DidYouGet-${{ steps.get_version.outputs.version }}-macos-x86_64.tar.gz -C x86_64 DidYouGet version.txt
        tar -czf DidYouGet-${{ steps.get_version.outputs.version }}-macos-arm64.tar.gz -C arm64 DidYouGet version.txt
        tar -czf DidYouGet-${{ steps.get_version.outputs.version }}-macos-universal.tar.gz -C universal DidYouGet version.txt
    
    - name: Create GitHub Release (if tag push)
      if: github.event_name == 'push'
      uses: softprops/action-gh-release@v1
      with:
        tag_name: ${{ steps.get_version.outputs.tag }}
        name: Release ${{ steps.get_version.outputs.version }}
        body: |
          # Release ${{ steps.get_version.outputs.version }}
          
          ## Downloads
          - **Universal Binary** (recommended): `DidYouGet-${{ steps.get_version.outputs.version }}-macos-universal.tar.gz`
          - **Intel Macs**: `DidYouGet-${{ steps.get_version.outputs.version }}-macos-x86_64.tar.gz`
          - **Apple Silicon Macs**: `DidYouGet-${{ steps.get_version.outputs.version }}-macos-arm64.tar.gz`
          
          ## Installation
          1. Download the appropriate file for your Mac
          2. Extract: `tar -xzf DidYouGet-${{ steps.get_version.outputs.version }}-macos-*.tar.gz`
          3. Run: `./DidYouGet`
          
          ## Requirements
          - macOS 13.0 or later
          - Screen recording permissions may be required
        files: |
          release/DidYouGet-${{ steps.get_version.outputs.version }}-macos-universal.tar.gz
          release/DidYouGet-${{ steps.get_version.outputs.version }}-macos-x86_64.tar.gz
          release/DidYouGet-${{ steps.get_version.outputs.version }}-macos-arm64.tar.gz
        draft: false
        prerelease: false
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Upload multiplatform artifacts
      uses: actions/upload-artifact@v3
      with:
        name: multiplatform-release
        path: |
          release/DidYouGet-${{ steps.get_version.outputs.version }}-macos-*.tar.gz
        retention-days: 90
```

## Setup Instructions

1. Create the `.github/workflows/` directory in your repository
2. Copy each workflow file to the appropriate location
3. Commit and push the workflow files
4. The workflows will automatically run on the configured triggers

## Testing the Workflows

- **CI**: Push to main branch or create a pull request
- **Release**: Push a tag like `v1.0.1`
- **Multiplatform**: Will run automatically on tag pushes or can be triggered manually

These workflows provide comprehensive CI/CD with testing, linting, and multi-architecture builds for your DidYouGet application.