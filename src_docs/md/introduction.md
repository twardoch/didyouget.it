# 1. Introduction

## What is Did You Get It?

Did You Get It is a high-performance macOS screen recording application designed for users who need professional-quality recordings with minimal system overhead and maximum flexibility. Built with Swift and SwiftUI, it leverages Apple's latest ScreenCaptureKit framework to deliver 60 FPS, full-resolution (Retina) video capture alongside comprehensive input tracking capabilities.

## Key Design Principles

### Performance First
- **Zero-compromise quality**: Native 60 FPS recording at full Retina resolution
- **Minimal system impact**: Optimized memory usage and CPU efficiency
- **Real-time processing**: Live audio mixing and input tracking without bottlenecks

### Minimal, Purposeful Interface
- **Extreme simplicity**: Only essential controls visible
- **Keyboard-driven workflow**: Minimal mouse interaction required
- **Distraction-free recording**: UI gets out of your way when recording

### Developer-Friendly Output
- **Structured data formats**: JSON for input tracking data
- **Flexible file organization**: Configurable output locations and naming
- **Integration-ready**: Designed for workflow automation and scripting

## What Makes It Different?

### Comprehensive Input Tracking
Unlike basic screen recorders that only capture video, Did You Get It simultaneously records:
- **Mouse movements** with pixel-perfect accuracy
- **Click events** with press/release timing
- **Keyboard input** with precise keystroke timing
- **All data in structured JSON format**

### Professional Audio Handling
- **Multi-source recording**: System audio, microphone, or both
- **Real-time mixing**: Combine multiple audio sources seamlessly
- **High-quality output**: Lossless audio capture options

### Configurable Recording Areas
- **Multi-display support**: Record from any connected display
- **Custom regions**: Define specific screen areas to capture
- **Dynamic adjustment**: Change recording parameters without stopping

## Use Cases

### Software Development & Demos
- **Bug reproduction**: Capture exact user interactions for debugging
- **Feature demonstrations**: Show new functionality with context
- **Tutorial creation**: Record step-by-step processes with input data

### UX Research & Testing
- **User session recording**: Capture complete user interactions
- **Usability analysis**: Review mouse patterns and keyboard usage
- **Performance testing**: Monitor system behavior during tasks

### Content Creation
- **Educational content**: Create detailed tutorials and walkthroughs
- **Product showcases**: Professional-quality demonstrations
- **Training materials**: Comprehensive learning resources

### Workflow Automation
- **Process documentation**: Record and analyze repetitive tasks
- **Automation scripting**: Use input data to create automation scripts
- **Quality assurance**: Validate user interface interactions

## System Requirements

### macOS Version Support
- **Minimum**: macOS 13.0 (Ventura)
- **Recommended**: macOS 14.0 (Sonoma) or later
- **Framework dependencies**: ScreenCaptureKit, AVFoundation, SwiftUI

### Hardware Requirements
- **Memory**: 8GB RAM minimum, 16GB recommended for 4K recording
- **Storage**: SSD recommended for high-framerate recording
- **Display**: Any Mac with Retina display support

### Permissions Required
- **Screen Recording**: Essential for video capture functionality
- **Microphone Access**: Required for audio recording (if enabled)
- **Accessibility**: Needed for comprehensive input tracking

## Privacy & Security

### Data Handling
- **Local processing only**: No cloud uploads or external data transmission
- **User-controlled storage**: All recordings saved to user-specified locations
- **Transparent permissions**: Clear explanation of required system access

### Security Considerations
- **Sandboxed execution**: Runs within macOS security boundaries
- **Minimal permissions**: Requests only necessary system access
- **Code signing**: Verified developer identity and integrity

## Getting Help

### Documentation Resources
- **Complete user guide**: Step-by-step instructions for all features
- **Developer documentation**: Architecture and API reference
- **Troubleshooting guide**: Solutions for common issues

### Community & Support
- **GitHub repository**: Source code, issues, and discussions
- **Feature requests**: Community-driven development priorities
- **Bug reports**: Collaborative issue resolution

Ready to get started? Continue to [Getting Started](getting-started.md) for installation and setup instructions.